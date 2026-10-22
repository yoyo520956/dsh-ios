import Foundation
import Combine

/// dsh web 运行时：iSH 内核 boot → `dsh web --no-open --port 3080` → 健康检查 → WKWebView 直连。
/// iSH 的 socket 直通宿主进程（fs/sock.c: fd->real_fd = socket(...)），
/// 因此 iSH 内 listen 的 127.0.0.1:3080 与 WKWebView 同进程可见，零桥接。
@MainActor
final class DshRuntime: ObservableObject {
    static let shared = DshRuntime()

    enum Phase: Equatable {
        case idle
        case bootingIsh
        case startingDsh
        case serving
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var logTail: [String] = []

    let port = 3080
    /// 机器级 patch 层（原版机制：覆盖所有 profile，优先级最高）
    static let dshHome = "/root/.dsh-home"
    var baseURL: String { "http://127.0.0.1:\(port)" }

    private var pollTimer: Timer?
    private var healthTimer: Timer?
    private var healthDeadline: Date?
    private var dshExitCount = 0
    private var launched = false

    private init() {}

    func start() {
        guard phase == .idle || isFailed else { return }
        phase = .bootingIsh
        appendLog("[dsh] iSH 内核启动中…")
        IshEngine.shared.ensureBoot()
        startPoll()
    }

    private var isFailed: Bool {
        if case .failed = phase { return true } else { return false }
    }

    /// 轮询 iSH boot phase → ready 后起 dsh
    private func startPoll() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                switch IshEngine.shared.phase {
                case .ready:
                    self.pollTimer?.invalidate()
                    self.launchDsh()
                case .failed(let msg):
                    self.pollTimer?.invalidate()
                    self.phase = .failed("iSH: \(msg)")
                    self.appendLog("[dsh] iSH 启动失败: \(msg)")
                default:
                    break
                }
            }
        }
    }

    /// 启动原版 dsh web（DSH_HOME 指向可写目录；失败自动退避重启 ≤5 次）
    private func launchDsh() {
        guard !launched else { return }
        launched = true
        phase = .startingDsh
        appendLog("[dsh] 启动原版 dsh web (port \(port))…")
        let script = "mkdir -p \(Self.dshHome) && export DSH_HOME=\(Self.dshHome) && exec /usr/bin/dsh web --no-open --port \(port) 2>&1"
        IshEngine.shared.startSession(
            command: ["/bin/sh", "-c", script],
            onOutput: { [weak self] data in
                Task { @MainActor in
                    let s = String(data: data, encoding: .utf8) ?? ""
                    for line in s.split(separator: "\n") { self?.appendLog("[dsh] \(line)") }
                }
            },
            onExit: { [weak self] code in
                Task { @MainActor in
                    guard let self else { return }
                    self.appendLog("[dsh] 进程退出 rc=\(code)")
                    self.dshExitCount += 1
                    self.launched = false
                    if self.dshExitCount <= 5 {
                        self.appendLog("[dsh] 3s 后自动重启（第 \(self.dshExitCount) 次）")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.launchDsh() }
                    } else if self.phase != .serving {
                        self.phase = .failed("dsh 反复退出（\(self.dshExitCount) 次），看终端日志")
                    }
                }
            },
            done: { [weak self] rc in
                Task { @MainActor in
                    self?.appendLog("[dsh] 会话句柄 rc=\(rc)")
                    self?.startHealthCheck()
                }
            }
        )
    }

    /// 健康检查：HTTP GET 首页成功即 serving
    private func startHealthCheck() {
        healthTimer?.invalidate()
        healthDeadline = Date().addingTimeInterval(150)
        healthTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let deadline = self.healthDeadline, Date() > deadline {
                    self.healthTimer?.invalidate()
                    if self.phase != .serving {
                        self.phase = .failed("健康检查超时（150s），看终端页日志")
                        self.appendLog("[dsh] 健康检查超时")
                    }
                    return
                }
                let ok = await self.probe()
                if ok {
                    self.healthTimer?.invalidate()
                    if self.phase != .serving {
                        self.phase = .serving
                        self.appendLog("[dsh] 服务就绪 → \(self.baseURL)")
                    }
                }
            }
        }
    }

    private func probe() async -> Bool {
        guard let url = URL(string: "\(baseURL)/") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// 重启 dsh（配置变更后调用）：杀旧进程 + 重新拉起
    func restartDsh() {
        appendLog("[dsh] 重启：杀旧进程…")
        phase = .startingDsh
        IshEngine.shared.startSession(
            command: ["/bin/sh", "-c", "pkill -f 'dsh web' 2>/dev/null; sleep 1; echo killed"],
            onOutput: { _ in },
            onExit: { _ in },
            done: { [weak self] _ in
                Task { @MainActor in
                    self?.launched = false
                    self?.launchDsh()
                }
            }
        )
    }

    func appendLog(_ line: String) {
        logTail.append(line)
        if logTail.count > 200 { logTail.removeFirst(logTail.count - 200) }
    }
}

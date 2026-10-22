import Foundation

// App 内日志（设置→关于→运行日志 可见；排查上下文/工具问题用）
public final class DSHLog {
    public static let shared = DSHLog()
    private var lines: [String] = []
    private let lock = NSLock()
    public static let max = 200

    public static func log(_ text: String) {
        shared.append(text)
    }
    private func append(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
        lines.append("[\(df.string(from: Date()))] \(text)")
        if lines.count > DSHLog.max { lines.removeFirst(lines.count - DSHLog.max) }
    }
    public func snapshot() -> [String] { lock.lock(); defer { lock.unlock() }; return lines }
}

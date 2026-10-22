import SwiftUI
import WebKit

/// 原版 DeepSeek Harness Web UI：WKWebView 直连 iSH 内 dsh web（127.0.0.1:3080）
struct DshWebView: View {
    @EnvironmentObject var runtime: DshRuntime

    var body: some View {
        Group {
            switch runtime.phase {
            case .serving:
                DshWebContainer(baseURL: runtime.baseURL)
            case .idle, .bootingIsh:
                statusPage("iSH 内核启动中…", detail: "首次启动导入 rootfs 需要一点时间")
            case .startingDsh:
                statusPage("正在启动原版 dsh web…", detail: "启动后 WKWebView 直连 127.0.0.1:\(runtime.port)")
            case .failed(let msg):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("启动失败").font(.title3.bold())
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("重试") { runtime.restartDsh() }
                        .buttonStyle(.borderedProminent)
                    NavigationLink("看终端日志") { TerminalView() }
                        .font(.footnote)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("DeepSeek Harness")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusPage(_ title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text(title).font(.title3.bold())
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            ForEach(runtime.logTail.suffix(5), id: \.self) { line in
                Text(line)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// WKWebView 容器：加载原版 Web UI
struct DshWebContainer: UIViewRepresentable {
    let baseURL: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        if let url = URL(string: baseURL) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            HarnessLog.shared.add("[web] 加载失败 \(error.localizedDescription)")
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            HarnessLog.shared.add("[web] 连接失败 \(error.localizedDescription)")
        }
    }
}

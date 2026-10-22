import Foundation

// 工具 3/4：网页抓取（原版 webfetch 的 iOS 版：UA 伪装 + 正文抽取）
public struct DSHWebTool: DSHAgentTool {
    public let name = "webfetch"
    public let description = "抓取网页正文（去导航/广告）。参数：{url: \"https://...\"}，返回净化文本前 6000 字"
    public var schema: [String: Any] { ["type": "object", "properties": ["url": ["type": "string"], "required": ["url"]] }
    public init() {}

    public func execute(args: String) async throws -> String {
        guard let d = args.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let urlS = o["url"] as? String, let url = URL(string: urlS) else { return "参数错误：需要 url" }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode ?? 0 < 400,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else { return "抓取失败" }
        let text = stripHTML(html)
        return text.count > 6000 ? String(text.prefix(6000)) + "\n…[截断]" : text
    }
    private func stripHTML(_ h: String) -> String {
        var s = h
        for (re, repl) in [("<script[\\s\\S]*?</script>", ""), ("<style[\\s\\S]*?</style>", ""), ("<[^>]+>", "\n"), ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\"")] {
            s = s.replacingOccurrences(of: re, with: repl, options: .regularExpression)
        }
        return s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

// 工具 4/4：搜索（DuckDuckGo HTML 端免 key，原版 search 的 iOS 版）
public struct DSHSearchTool: DSHAgentTool {
    public let name = "search"
    public let description = "联网搜索（DuckDuckGo）。参数 {query: \"关键词\"}，返回前 8 条标题+摘要+链接"
    public var schema: [String: Any] { ["type": "object", "properties": ["query": ["type": "string"], "required": ["query"]] }
    public init() {}

    public func execute(args: String) async throws -> String {
        guard let d = args.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let q = o["query"] as? String else { return "参数错误：需要 query" }
        guard let qq = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://html.duckduckgo.com/html/?q=\(qq)") else { return "搜索失败" }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req), let html = String(data: data, encoding: .utf8) else { return "搜索请求失败" }
        let titles = matches(html, pattern: "<a[^>]*class=\"result__a\"[^>]*>([\\s\\S]*?)</a>")
        let links = matches(html, pattern: "class=\"result__url\"[\\s\\S]*?href=\"([^\"]+)\"").map { strip($0) }
        let snips = matches(html, pattern: "class=\"result__snippet\"[^>]*>([\\s\\S]*?)</a>").map(strip)
        var out = ""; for i in 0..<min(8, titles.count) {
            out += "\(i + 1). \(strip(titles[i]))\n"
            if i < links.count { out += "   \(links[i])\n" }
            if i < snips.count { out += "   \(snips[i].prefix(240))\n" }
            out += "\n"
        }
        return out.isEmpty ? "无结果" : out
    }
    private func matches(_ s: String, pattern: String) -> [String] {
        (try? NSRegularExpression(pattern: pattern))?.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range(at: 1), in: s)!]) } ?? []
    }
    private func strip(_ s: String) -> String { s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines) }
}

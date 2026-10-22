import Foundation

// 工具注册表（plugin enabled → tool ids）
public enum DSHToolRegistry {
    static let file = DSHFileTool()
    static let bash = DSHBashTool()
    static let web = DSHWebTool()
    static let search = DSHSearchTool()

    public static func tool(_ id: String) -> DSHAgentTool? {
        switch id {
        case "file": return file
        case "bash": return bash
        case "webfetch", "web": return web
        case "search": return search
        default: return nil
        }
    }

    public static func wireSchemas(_ ids: [String]) -> [[String: Any]] {
        var seen = Set<String>()
        return ids.compactMap { id -> [String: Any]? in
            let key: String
            switch id { case "webfetch", "web": key = "webfetch"; default: key = id }
            guard !seen.contains(key), let t = tool(id) else { return nil }
            seen.insert(key)
            return t.wire
        }
    }
}

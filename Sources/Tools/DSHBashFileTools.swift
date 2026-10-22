import Foundation

// 工具 1/4：文件（沙盒 = Documents/DSH，对应原版 file 工具 iOS 化）
public struct DSHFileTool: DSHAgentTool {
    public let name = "file"
    public let description = "读写列改沙盒文件。参数 JSON：{action: read|write|list|edit, path: 相对沙盒路径, content?: 写内容, old?: edit 原文, new?: edit 新文}"
    public var schema: [String: Any] {
        var m: [String: Any] = ["type": "object"]
        m["properties"] = [
            "action": ["type": "string", "enum": ["read", "write", "list", "edit"]],
            "path": ["type": "string"],
            "content": ["type": "string"],
            "old": ["type": "string"], "new": ["type": "string"]]
        m["required"] = ["action", "path"]
        return m
    }

    public init() {}

    private var root: URL { DSHStore.sandboxURL }

    public func execute(args: String) async throws -> String {
        guard let d = args.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let action = o["action"] as? String, let path = o["path"] as? String else { return "参数错误：需要 action+path" }
        let url = root.appendingPathComponent(path)
        let fm = FileManager.default
        switch action {
        case "read":
            guard fm.fileExists(atPath: url.path), let s = try? String(contentsOf: url, encoding: .utf8) else { return "文件不存在：\(path)" }
            return s.count > 20000 ? String(s.prefix(20000)) + "\n…[截断 \(s.count) 字符]" : s
        case "write":
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard let content = o["content"] as? String else { return "write 需要 content" }
            do { try content.write(to: url, atomically: true, encoding: .utf8); return "已写入 \(path)（\(content.count) 字符）" }
            catch { return "写入失败：\(error.localizedDescription)" }
        case "list":
            let items = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
            if items.isEmpty { return "空目录或不存在" }
            return items.map { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? "d  \($0.lastPathComponent)" : "f  \($0.lastPathComponent)" }.joined(separator: "\n")
        case "edit":
            guard let old = o["old"] as? String, let new = o["new"] as? String, let content = try? String(contentsOf: url, encoding: .utf8), content.contains(old) else { return "原文未找到" }
            try? content.replacingOccurrences(of: old, with: new).write(to: url, atomically: true, encoding: .utf8)
            return "已替换 \(path)"
        default: return "未知 action"
        }
    }
}

// 工具 2/4：终端（沙盒命令子集——原版 bash 的 iOS 可行版，参考鲸聊 ShellEngine）
public struct DSHBashTool: DSHAgentTool {
    public let name = "bash"
    public let description = "沙盒内执行命令子集：ls/cd/cat/mkdir/rm/cp/mv/echo/head/tail/wc/grep/find/pwd/date/touch/tree，支持单管道。参数：{command: \"ls -l\"}"
    public var schema: [String: Any] {
        var m: [String: Any] = ["type": "object"]
        m["properties"] = ["command": ["type": "string"]]
        m["required"] = ["command"]
        return m
    }
    public init() {}
    private var root: URL { DSHStore.sandboxURL }
    private var cwd: URL { root }

    public func execute(args: String) async throws -> String {
        guard let d = args.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let cmd = o["command"] as? String else { return "参数错误：需要 command" }
        return runCommand(cmd)
    }

    func runCommand(_ line: String) -> String {
        var comps = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !comps.isEmpty else { return "" }
        var input = ""
        var out = ""
        while !comps.isEmpty {
            let c = comps.removeFirst()
            let argv = splitArgs(c)
            out = exec(argv, stdin: input)
            input = out
        }
        return out.count > 12000 ? String(out.prefix(12000)) + "\n…[截断]" : out
    }

    private func splitArgs(_ s: String) -> [String] {
        var res: [String] = []; var cur = ""; var quote = false
        for ch in s {
            if ch == "\"" { quote.toggle(); continue }
            if ch == " ", !quote { if !cur.isEmpty { res.append(cur); cur = "" } } else { cur.append(ch) }
        }
        if !cur.isEmpty { res.append(cur) }
        return res
    }

    private func exec(_ argv: [String], stdin: String) -> String {
        guard let cmd = argv.first else { return "" }
        let a = Array(argv.dropFirst())
        let fm = FileManager.default
        let resolve: (String) -> URL = { cwd.appendingPathComponent($0.replacingOccurrences(of: "~", with: "")) }
        switch cmd {
        case "pwd": return cwd.path
        case "date": return ISO8601DateFormatter().string(from: Date())
        case "echo": return a.joined(separator: " ")
        case "ls", "ll":
            let url = a.first.map(resolve) ?? cwd
            guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey]) else { return "ls: 无法读取" }
            return items.map { i in
                let isDir = (try? i.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return isDir ? "d  \(i.lastPathComponent)/" : "f  \(i.lastPathComponent)  \((try? i.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)B"
            }.joined(separator: "\n")
        case "cat":
            guard let p = a.first else { return "cat: 缺文件" }
            guard let s = try? String(contentsOf: resolve(p), encoding: .utf8) else { return "cat: 读不到 \(p)" }
            return s.count > 12000 ? String(s.prefix(12000)) + "\n…[截断]" : s
        case "mkdir": guard let p = a.first else { return "mkdir: 缺目录" }; try? fm.createDirectory(at: resolve(p), withIntermediateDirectories: true); return "ok"
        case "touch": guard let p = a.first else { return "touch: 缺文件" }; fm.createFile(atPath: resolve(p).path, contents: Data()); return "ok"
        case "rm": guard let p = a.first else { return "rm: 缺路径" }; try? fm.removeItem(atPath: resolve(p).path); return "ok"
        case "cp", "mv":
            guard a.count >= 2 else { return "\(cmd): 缺源/目标" }
            let src = resolve(a[0]); var dst = resolve(a[1])
            if (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false { dst = dst.appendingPathComponent(src.lastPathComponent) } else if (try? dst.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false { dst = dst.appendingPathComponent(src.lastPathComponent) }
            if cmd == "cp" { try? fm.copyItem(atPath: src.path, toPath: dst.path) } else { try? fm.moveItem(atPath: src.path, toPath: dst.path) }
            return "ok"
        case "head", "tail":
            guard let p = a.first, let s = try? String(contentsOf: resolve(p), encoding: .utf8) else { return "\(cmd): 读不到" }
            let lines = s.components(separatedBy: "\n"); let n = Int(a.last ?? "10") ?? 10
            return (cmd == "head" ? lines.prefix(n) : lines.suffix(n)).joined(separator: "\n")
        case "wc": guard let s = try? String(contentsOf: resolve(a.first ?? ""), encoding: .utf8) else { return "wc: 读不到" }; return "行 \(s.components(separatedBy: "\n").count) 字 \(s.count)"
        case "grep":
            let rest = a.filter { !$0.hasPrefix("-") }
            guard rest.count >= 2 else { return "grep: 用法 grep 关键词 文件" }
            let kw = rest[0]; guard let s = try? String(contentsOf: resolve(rest[1]), encoding: .utf8) else { return "grep: 读不到" }
            return s.components(separatedBy: "\n").filter { $0.contains(kw) }.joined(separator: "\n")
        case "find":
            let kw = a.first?.replacingOccurrences(of: "*", with: "") ?? ""
            let deep = (try? fm.subpathsOfDirectory(atPath: cwd.path)) ?? []
            return deep.filter { kw.isEmpty || $0.contains(kw) }.prefix(300).joined(separator: "\n")
        case "tree":
            let deep = (try? fm.subpathsOfDirectory(atPath: cwd.path)) ?? []
            return deep.prefix(500).map { String(repeating: "  ", count: $0.components(separatedBy: "/").count - 1) + "/" + $0.components(separatedBy: "/").last! }.joined(separator: "\n")
        case "help": return "支持：ls ll cat mkdir touch rm cp mv head tail wc grep find tree echo date pwd help"
        default: return "\(cmd): 不支持（沙盒命令子集，help 查看）"
        }
    }
}

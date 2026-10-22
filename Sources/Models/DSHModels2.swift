import Foundation

// MARK: - Agent 预设（原版 Settings → Agent presets）
public struct DSHAgentPreset: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var systemPrompt: String
    public var toolIDs: [String]        // 启用的工具
    public var modelID: String?
    public var temperature: Double?
    public var builtin: Bool = false
    public init(name: String, systemPrompt: String, toolIDs: [String] = ["file","bash","webfetch","search"], modelID: String? = nil, builtin: Bool = false) {
        self.id = UUID(); self.name = name; self.systemPrompt = systemPrompt; self.toolIDs = toolIDs; self.modelID = modelID; self.builtin = builtin
    }
    public static let defaults: [DSHAgentPreset] = [
        DSHAgentPreset(name: "默认助手", systemPrompt: "你是 DeepSeek Harness 助手，严谨、直接、中文回复。", builtin: true),
        DSHAgentPreset(name: "代码搭子", systemPrompt: "你是资深工程师，先读代码再下结论，输出可编译的代码。", builtin: true),
        DSHAgentPreset(name: "研究员", systemPrompt: "你是调研专家，多源交叉验证，结论先行，附证据。", builtin: true),
    ]
}

// MARK: - 插件（原版 plugin-market 54 包 → iOS 声明式：prompt 包 + 工具扩展 + MCP 桥）
public struct DSHPlugin: Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var summary: String
    public var category: String         // agent / tools / providers / memory / workflow
    public var version: String
    public var installed: Bool
    public var enabled: Bool
    public var author: String
    public init(id: String, name: String, summary: String, category: String, version: String = "1.0.0", installed: Bool = false, enabled: Bool = true, author: String = "deepseek-ai") {
        self.id = id; self.name = name; self.summary = summary; self.category = category; self.version = version; self.installed = installed; self.enabled = enabled; self.author = author
    }
    // 原版 54 包按类分组（tool-catalog / module-graph 盘点，iOS 版同结构）
    public static let catalog: [DSHPlugin] = [
        DSHPlugin(id: "core-agent", name: "Agent Core", summary: "Agent 循环：思考→工具→观察→再思考", category: "agent"),
        DSHPlugin(id: "tools-file", name: "文件工具", summary: "读/写/列表/编辑沙盒文件", category: "tools"),
        DSHPlugin(id: "tools-bash", name: "终端工具", summary: "沙盒内命令执行（iOS 命令子集）", category: "tools"),
        DSHPlugin(id: "tools-web", name: "网页工具", summary: "抓取网页正文/链接/元信息", category: "tools"),
        DSHPlugin(id: "tools-search", name: "搜索工具", summary: "联网搜索（需自定义提供商）", category: "tools"),
        DSHPlugin(id: "memory-kv", name: "记忆层", summary: "跨会话长期记忆（本地 JSON）", category: "memory"),
        DSHPlugin(id: "mcp-bridge", name: "MCP 桥", summary: "连接远程 MCP 服务器（HTTP/SSE）", category: "agent"),
        DSHPlugin(id: "gateway", name: "API 网关", summary: "本机 OpenAI 兼容网关（局域网）", category: "providers"),
        DSHPlugin(id: "schedule", name: "计划任务", summary: "定时/间隔触发 agent 任务", category: "workflow"),
        DSHPlugin(id: "export", name: "导入导出", summary: "会话 Markdown/JSON 导出分享", category: "workflow"),
    ]
}

// MARK: - 计划任务（原版 schedule）
public struct DSHScheduleTask: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var hour: Int                 // 0-23
    public var minute: Int               // 0-59
    public var repeatMode: RepeatMode
    public var enabled: Bool
    public var lastFired: Date?
    public enum RepeatMode: String, Codable { case daily, weekdays, once }
    public init(name: String, prompt: String, hour: Int = 9, minute: Int = 0, repeat: RepeatMode = .daily) {
        self.id = UUID(); self.name = name; self.prompt = prompt; self.hour = hour; self.minute = minute; self.repeatMode = repeat; self.enabled = true
    }
}

// MARK: - 全局配置（原版 Settings → General）
public struct DSHConfig: Codable, Equatable {
    public var activeProviderID: String
    public var activeModelID: String
    public var activePresetID: UUID?
    public var temperature: Double = 0.7
    public var streamEnabled: Bool = true
    public var thinkingEnabled: Bool = false
    public var searchEnabled: Bool = false
    public var autoTitle: Bool = true
    public var sandboxRoot: String = "Documents/DSH"
    public init() { activeProviderID = "deepseek-official"; activeModelID = "deepseek-chat" }
}

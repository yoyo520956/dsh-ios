import Foundation

// MARK: - 消息模型（OpenAI wire 格式 + 扩展字段）
public struct DSHToolCall: Codable, Identifiable, Equatable {
    public var id: String { callID }
    public var callID: String
    public var name: String
    public var arguments: String          // JSON 字符串（流式时增量拼接）
    public var result: String? = nil      // 工具执行结果
    public var status: Status = .running
    public enum Status: String, Codable { case running, done, failed }
    public init(callID: String = UUID().uuidString, name: String, arguments: String = "", result: String? = nil, status: Status = .running) {
        self.callID = callID; self.name = name; self.arguments = arguments; self.result = result; self.status = status
    }
}

public struct DSHMessage: Codable, Identifiable, Equatable {
    public var id: UUID
    public var role: Role               // user / assistant / system / tool
    public var text: String
    public var reasoning: String?       // DeepSeek thinking 内容
    public var toolCalls: [DSHToolCall]?
    public var model: String?
    public var createdAt: Date
    public var finishedAt: Date?
    public var streamError: String?
    public enum Role: String, Codable { case system, user, assistant, tool }
    public init(role: Role, text: String = "", model: String? = nil) {
        self.id = UUID(); self.role = role; self.text = text; self.model = model; self.createdAt = Date()
    }
    public var wireRole: String { role.rawValue }
}

// MARK: - 会话
public struct DSHSession: Codable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var modelID: String
    public var messages: [DSHMessage]
    public var createdAt: Date
    public var updatedAt: Date
    public var pinned: Bool = false
    public init(title: String = "新会话", modelID: String) {
        self.id = UUID(); self.title = title; self.modelID = modelID
        self.messages = []; self.createdAt = Date(); self.updatedAt = Date()
    }
    public mutating func append(_ m: DSHMessage) { messages.append(m); updatedAt = Date() }
}

// MARK: - Provider（原版 providers 体系：官方/自定义 OpenAI 兼容）
public struct DSHProvider: Codable, Identifiable, Equatable {
    public var id: String                 // deepseek-official / custom-xxx
    public var label: String              // DeepSeek
    public var type: PType                // official / custom
    public var baseURL: String
    public var apiKey: String
    public var models: [DSHModel]
    public var enabled: Bool = true
    public enum PType: String, Codable { case deepseekOfficial = "deepseek-official", custom }
    public init(id: String, label: String, type: PType, baseURL: String, apiKey: String = "", models: [DSHModel]) {
        self.id = id; self.label = label; self.type = type; self.baseURL = baseURL; self.apiKey = apiKey; self.models = models
    }
    public static let builtinModels = [
        DSHModel(id: "deepseek-chat", label: "DeepSeek-V3", providerID: "deepseek-official", tools: true, thinking: false),
        DSHModel(id: "deepseek-reasoner", label: "DeepSeek-R1", providerID: "deepseek-official", tools: true, thinking: true),
    ]
}

public struct DSHModel: Codable, Identifiable, Equatable {
    public var id: String
    public var label: String
    public var providerID: String
    public var supportsTools: Bool
    public var supportsThinking: Bool
    public init(id: String, label: String, providerID: String, tools: Bool = true, thinking: Bool = false) {
        self.id = id; self.label = label; self.providerID = providerID; self.supportsTools = tools; self.supportsThinking = thinking
    }
}

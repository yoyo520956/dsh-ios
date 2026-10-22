import Foundation

// Agent 循环 v2：流式产出 + 工具调用自动执行回灌（原版 agent-lifecycle 的 iOS 复刻）
public protocol DSHAgentTool {
    var name: String { get }
    var description: String { get }
    var schema: [String: Any] { get }
    func execute(args: String) async throws -> String
}
public extension DSHAgentTool {
    var wire: [String: Any] { ["type": "function", "function": ["name": name, "description": description, "parameters": schema]] }
}

public enum DSHAPIErrorLocal: Error, Equatable { case noKey, badURL, http(Int, String), emptyResponse, cancelled, other(String) }

@MainActor
public final class DSHAgentRunner: ObservableObject {
    public enum Phase: Equatable { case idle, streaming, toolRunning(String), done, failed(String) }
    @Published public var phase: Phase = .idle
    @Published public var usage: (prompt: Int, completion: Int) = (0, 0)

    private let client = DSHAPIClient()
    private var taskHandle: Task<Void, Never>?

    public init() {}

    public func cancel() { taskHandle?.cancel(); phase = .done }

    public func run(userText: String) {
        guard let provider = DSHStore.shared.activeProvider, let model = DSHStore.shared.activeModel else { phase = .failed("未配置模型"); return }
        let toolIDs = DSHStore.shared.activePreset?.toolIDs ?? DSHStore.shared.plugins.filter(\.enabled).compactMap { p in
            p.category == "tools" ? String(p.id.split(separator: "-").last ?? "") : nil
        }
        let presetPrompt = DSHStore.shared.activePreset?.systemPrompt ?? "你是 DeepSeek Harness 助手，严谨、直接、中文回复。"
        taskHandle?.cancel()
        taskHandle = Task { [weak self] in
            guard let self else { return }
            let store = DSHStore.shared
            store.bindMutate { $0.append(DSHMessage(role: .user, text: userText, model: model.id)) }
            defer { self.phase = .done }
            do {
                var rounds = 0
                while rounds < 8 {
                    if Task.isCancelled { return }
                    rounds += 1
                    self.phase = .streaming
                    var wire: [[String: Any]] = [["role": "system", "content": presetPrompt]]
                    for m in store.sessions.first(where: { $0.id == store.activeSessionID })?.messages ?? [] {
                        switch m.role {
                        case .system: break
                        case .user: wire.append(["role": "user", "content": m.text])
                        case .assistant:
                            if let tcs = m.toolCalls, !tcs.isEmpty {
                                wire.append(["role": "assistant", "content": m.text, "tool_calls": tcs.map { ["id": $0.callID, "type": "function", "function": ["name": $0.name, "arguments": $0.arguments]] }])
                            } else { wire.append(["role": "assistant", "content": m.text]) }
                        case .tool:
                            if let tcs = m.toolCalls {
                                for tc in tcs { wire.append(["role": "tool", "tool_call_id": tc.callID, "content": tc.result ?? ""]) }
                            }
                        }
                    }
                    let tools = DSHToolRegistry.wireSchemas(toolIDs)
                    let outcome = try await self.streamOne(provider: provider, model: model, wire: wire, tools: tools, userText: userText, rounds: rounds)
                    if outcome.tools.isEmpty { return }
                    for call in outcome.tools {
                        if Task.isCancelled { return }
                        self.phase = .toolRunning(call.name)
                        guard let tool = DSHToolRegistry.tool(call.name) else {
                            ToolResult.write(callID: call.id, messageID: call.messageID, result: "未知工具 \(call.name)"); continue
                        }
                        var result = ""
                        do { result = try await tool.execute(args: call.args) } catch { result = "工具执行失败：\(error.localizedDescription)" }
                        ToolResult.write(callID: call.id, messageID: call.messageID, result: result)
                    }
                }
            } catch let e as DSHAPIError { self.phase = .failed(DSHText.err(e)) }
            catch { self.phase = .failed(error.localizedDescription) }
        }
    }

    struct ToolCall { let id: String; let name: String; let args: String; let messageID: UUID }

    private func streamOne(provider: DSHProvider, model: DSHModel, wire: [[String: Any]], tools: [[String: Any]], userText: String, rounds: Int) async throws -> (tools: [ToolCall], text: String) {
        let store = DSHStore.shared
        let temp = store.config.thinkingEnabled ? 0.0 : store.config.temperature
        var text = "", reasoning = ""
        var toolsOut: [ToolCall] = []
        var toolIndexMap: [String: Int] = [:]
        var assistantID: UUID?
        let stream = await client.streamChat(provider: provider, model: model, messages: wire, tools: tools, temperature: temp, thinking: store.config.thinkingEnabled)
        for try await ev in stream {
            if assistantID == nil {
                store.bindMutate { s in s.append(DSHMessage(role: .assistant, model: model.id)) }
                assistantID = store.sessions.first(where: { $0.id == store.activeSessionID })?.messages.last?.id
            }
            if let c = ev.contentDelta, !c.isEmpty { text += c; ToolResult.writeContent(assistantID, text: text) }
            if let r = ev.reasoningDelta { reasoning += r; ToolResult.writeReasoning(assistantID, reasoning: reasoning) }
            if let d = ev.toolCallDelta {
                let key = "\(d.index)"
                var args = store.activeSession?.messages.first(where: { $0.id == assistantID })?.toolCalls ?? []
                let idx = toolIndexMap[key] ?? { let n = args.count; toolIndexMap[key] = n; return n }()
                if args.count <= idx { args.append(DSHToolCall(name: "")) }
                if let id = d.id, !id.isEmpty { args[idx].callID = id }
                if let n = d.name { args[idx].name = n }
                if let a = d.argsDelta { args[idx].arguments += a }
                ToolResult.writeTools(assistantID, tools: args)
            }
            if let u = ev.usage { self.usage = (self.usage.prompt + u.prompt, self.usage.completion + u.completion) }
        }
        if let aid = assistantID {
            let tcs = store.sessions.first(where: { $0.id == store.activeSessionID })?.messages.first(where: { $0.id == aid })?.toolCalls ?? []
            toolsOut = tcs.map { ToolCall(id: $0.callID, name: $0.name, args: $0.arguments, messageID: aid) }
        }
        return (toolsOut, text)
    }
}

public enum ToolResult {
    public static func writeContent(_ id: UUID?, text: String) {
        guard let id, let sid = DSHStore.shared.activeSessionID, let si = DSHStore.shared.sessions.firstIndex(where: { $0.id == sid }), let mi = DSHStore.shared.sessions[si].messages.firstIndex(where: { $0.id == id }) else { return }
        DSHStore.shared.bindMutate { $0.messages[mi].text = text }
    }
    public static func writeReasoning(_ id: UUID?, reasoning: String) {
        guard let id, let sid = DSHStore.shared.activeSessionID, let si = DSHStore.shared.sessions.firstIndex(where: { $0.id == sid }), let mi = DSHStore.shared.sessions[si].messages.firstIndex(where: { $0.id == id }) else { return }
        DSHStore.shared.bindMutate { $0.messages[mi].reasoning = reasoning }
    }
    public static func writeTools(_ id: UUID?, tools: [DSHToolCall]) {
        guard let id, let sid = DSHStore.shared.activeSessionID, let si = DSHStore.shared.sessions.firstIndex(where: { $0.id == sid }), let mi = DSHStore.shared.sessions[si].messages.firstIndex(where: { $0.id == id }) else { return }
        DSHStore.shared.bindMutate { $0.messages[mi].toolCalls = tools }
    }
    public static func write(callID: String, messageID: UUID, result: String) {
        guard let sid = DSHStore.shared.activeSessionID, let si = DSHStore.shared.sessions.firstIndex(where: { $0.id == sid }), let mi = DSHStore.shared.sessions[si].messages.firstIndex(where: { $0.id == messageID }), let ti = DSHStore.shared.sessions[si].messages[mi].toolCalls?.firstIndex(where: { $0.callID == callID }) else { return }
        DSHStore.shared.bindMutate { $0.messages[mi].toolCalls?[ti].result = result; $0.messages[mi].toolCalls?[ti].status = .done }
    }
}

public enum DSHText {
    public static func err(_ e: DSHAPIError) -> String {
        switch e {
        case .noKey: return "未配置 API Key（设置 → 模型）"
        case .badURL: return "Base URL 不合法"
        case .http(let c, let b): return "上游 HTTP \(c)：\(b.prefix(200))"
        case .emptyResponse: return "上游返回空"
        case .cancelled: return "已停止"
        case .other(let s): return s
        }
    }
}

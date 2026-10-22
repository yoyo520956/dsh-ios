import Foundation

// DeepSeek 官方 + OpenAI 兼容 provider 统一客户端
public enum DSHAPIError: Error, Equatable { case noKey, badURL, http(Int, String), emptyResponse, cancelled, other(String) }

public struct DSHStreamEvent {
    public var contentDelta: String?
    public var reasoningDelta: String?
    public var toolCallDelta: (index: Int, id: String?, name: String?, argsDelta: String?)?
    public var finishReason: String?
    public var usage: (prompt: Int, completion: Int)?
}

public actor DSHAPIClient {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public nonisolated static let officialBase = "https://api.deepseek.com"

    public func streamChat(
        provider: DSHProvider, model: DSHModel,
        messages: [[String: Any]],          // wire messages
        tools: [[String: Any]]?,
        temperature: Double, thinking: Bool
    ) -> AsyncThrowingStream<DSHStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let events = try await self.streamOnce(provider: provider, model: model, messages: messages, tools: tools, temperature: temperature, thinking: thinking)
                    for e in events { if Task.isCancelled { throw DSHAPIError.cancelled }; continuation.yield(e) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamOnce(provider: DSHProvider, model: DSHModel, messages: [[String: Any]], tools: [[String: Any]]?, temperature: Double, thinking: Bool) async throws -> [DSHStreamEvent] {
        guard !provider.apiKey.isEmpty else { throw DSHAPIError.noKey }
        guard var url = URL(string: provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/") ? String(provider.baseURL.dropLast()) + "/chat/completions" : provider.baseURL + "/chat/completions") else { throw DSHAPIError.badURL }
        if provider.type == .custom { url = normalizeCustom(url) }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 120
        var payload: [String: Any] = [
            "model": model.id, "messages": messages, "stream": true,
            "temperature": temperature,
        ]
        if thinking && model.supportsThinking { payload["thinking"] = true }
        if let tools, !tools.isEmpty, model.supportsTools { payload["tools"] = tools; payload["tool_choice"] = "auto" }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (bytes, resp) = try await session.bytes(for: req)
        guard let http = resp as? HTTPURLResponse else { throw DSHAPIError.other("no response") }
        guard (200..<300).contains(http.statusCode) else {
            var body = ""; for try await line in bytes.lines { body += line; if body.count > 2000 { break } }
            throw DSHAPIError.http(http.statusCode, body)
        }
        return try await parseSSE(bytes)
    }

    private func normalizeCustom(_ u: URL) -> URL {
        var s = u.absoluteString
        if s.hasSuffix("/v1/v1") { s = s.replacingOccurrences(of: "/v1/v1", with: "/v1") }
        if !s.contains("/v1/") && !s.contains("/chat/completions") {
            s = s.replacingOccurrences(of: "/chat/completions", with: "/v1/chat/completions", options: .literal, range: nil)
        }
        return URL(string: s) ?? u
    }

    private func parseSSE(_ bytes: URLSession.AsyncBytes) async throws -> [DSHStreamEvent] {
        var out: [DSHStreamEvent] = []
        var json = JSONSerialization()
        for try await line in bytes.lines {
            if Task.isCancelled { throw DSHAPIError.cancelled }
            guard line.hasPrefix("data:") else { continue }
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if data == "[DONE]" { break }
            guard let d = data.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
            guard let choices = obj["choices"] as? [[String: Any]], let ch = choices.first else { continue }
            let delta = ch["delta"] as? [String: Any] ?? [:]
            if let c = delta["content"] as? String, !c.isEmpty {
                out.append(DSHStreamEvent(contentDelta: c))
            }
            if let r = delta["reasoning_content"] as? String, !r.isEmpty {
                out.append(DSHStreamEvent(reasoningDelta: r))
            }
            if let tcs = delta["tool_calls"] as? [[String: Any]] {
                for (i, tc) in tcs.enumerated() {
                    let f = tc["function"] as? [String: Any] ?? [:]
                    out.append(DSHStreamEvent(toolCallDelta: (
                        index: (tc["index"] as? Int) ?? i,
                        id: tc["id"] as? String,
                        name: f["name"] as? String,
                        argsDelta: f["arguments"] as? String
                    )))
                }
            }
            if let fr = ch["finish_reason"] as? String { out.append(DSHStreamEvent(finishReason: fr)) }
            if let usage = obj["usage"] as? [String: Any] {
                out.append(DSHStreamEvent(usage: (prompt: usage["prompt_tokens"] as? Int ?? 0, completion: usage["completion_tokens"] as? Int ?? 0)))
            }
        }
        _ = bytes
        if out.isEmpty { throw DSHAPIError.emptyResponse }
        return out
    }
}

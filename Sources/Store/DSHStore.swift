import Foundation

// 全部状态单例（ObservableObject）+ JSON 文件持久化（Documents/DSH/state.json，大上限 8000 消息防爆）
public final class DSHStore: ObservableObject {
    public static let shared = DSHStore()

    // MARK: 状态
    @Published public var providers: [DSHProvider] = []
    @Published public var sessions: [DSHSession] = []
    @Published public var config = DSHConfig()
    @Published public var presets: [DSHAgentPreset] = DSHAgentPreset.defaults
    @Published public var plugins: [DSHPlugin] = DSHPlugin.catalog
    @Published public var tasks: [DSHScheduleTask] = []
    @Published public var activeSessionID: UUID?
    @Published public var autoRunPrompt: String?

    private let fm = FileManager.default
    private lazy var stateURL: URL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("DSH", isDirectory: true)
        .appendingPathComponent("state.json")

    private init() { load() }

    public var activeSession: DSHSession? {
        get { sessions.first(where: { $0.id == activeSessionID }) }
        set { if let v = newValue, let i = sessions.firstIndex(where: { $0.id == v.id }) { sessions[i] = v; save() } }
    }
    public var activeProvider: DSHProvider? { providers.first(where: { $0.id == config.activeProviderID }) ?? providers.first }
    public var activeModel: DSHModel? {
        guard let p = activeProvider else { return nil }
        if let m = p.models.first(where: { $0.id == config.activeModelID }) { return m }
        return p.models.first
    }
    public var activePreset: DSHAgentPreset? { presets.first(where: { $0.id == config.activePresetID }) }

    // MARK: 会话操作
    public func newSession() -> DSHSession {
        let s = DSHSession(modelID: config.activeModelID)
        sessions.insert(s, at: 0); activeSessionID = s.id; save(); return s
    }
    public func deleteSession(_ id: UUID) { sessions.removeAll { $0.id == id }; if activeSessionID == id { activeSessionID = sessions.first?.id }; save() }
    public func renameSession(_ id: UUID, title: String) { if let i = sessions.firstIndex(where: { $0.id == id }) { sessions[i].title = title; save() } }
    public func bindMutate(_ mutate: @escaping (inout DSHSession) -> Void) {
        guard let id = activeSessionID, let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        mutate(&sessions[i]); save()
    }
    public func trimHistory() {
        let cap = 8000
        if sessions.count * 50 > cap { sessions = Array(sessions.prefix(200)) }
    }

    // MARK: Provider/Plugin 操作
    public func upsertProvider(_ p: DSHProvider) {
        if let i = providers.firstIndex(where: { $0.id == p.id }) { providers[i] = p } else { providers.append(p) }
        save()
    }
    public func upsertPlugin(_ p: DSHPlugin) {
        if let i = plugins.firstIndex(where: { $0.id == p.id }) { plugins[i] = p } else { plugins.append(p) }
        save()
    }


    // MARK: 持久化
    struct State: Codable {
        var providers: [DSHProvider]?
        var sessions: [DSHSession]?
        var config: DSHConfig?
        var presets: [DSHAgentPreset]?
        var plugins: [DSHPlugin]?
        var tasks: [DSHScheduleTask]?
        var activeSessionID: UUID?
    }
    public func save() {
        trimHistory()
        let st = State(providers: providers, sessions: sessions, config: config, presets: presets, plugins: plugins, tasks: tasks, activeSessionID: activeSessionID)
        do {
            try fm.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
            try enc.encode(st).write(to: stateURL, options: .atomic)
            // 沙盒目录同建（tools file 用）
            try? fm.createDirectory(at: DSHStore.sandboxURL, withIntermediateDirectories: true)
        } catch { print("[DSH] save fail: \(error)") }
    }
    public func load() {
        guard let data = try? Data(contentsOf: stateURL) else { bootstrap(); return }
        do {
            let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
            let st = try dec.decode(State.self, from: data)
            providers = st.providers ?? providers
            sessions = st.sessions ?? sessions
            config = st.config ?? config
            presets = st.presets ?? presets
            plugins = st.plugins ?? plugins
            tasks = st.tasks ?? tasks
            activeSessionID = st.activeSessionID ?? sessions.first?.id
        } catch { print("[DSH] load fail: \(error)"); bootstrap() }
    }
    private func bootstrap() {
        if providers.isEmpty {
            providers = [DSHProvider(id: "deepseek-official", label: "DeepSeek", type: .deepseekOfficial, baseURL: DSHAPIClient.officialBase, models: DSHProvider.builtinModels)]
            save()
        }
    }
    public static var sandboxURL: URL { fm0.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("DSH", isDirectory: true) }
    private static let fm0 = FileManager.default
}

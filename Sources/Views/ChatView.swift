import SwiftUI

struct ChatView: View {
    @EnvironmentObject var store: DSHStore
    @EnvironmentObject var runner: DSHAgentRunner
    @State private var input = ""
    @State private var showModelPicker = false
    @FocusState private var focused: Bool

    private var session: DSHSession? { store.activeSession }

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏（原版对话标题栏：标题 + 模型 + 状态）
            HStack(spacing: DSW.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session?.title ?? "新会话").font(DSW.TypeScale.headline).lineLimit(1)
                    HStack(spacing: 4) {
                        Text(store.activeModel?.label ?? "未配置模型").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.link)
                        if store.config.thinkingEnabled {
                            Text("· 思考").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                        }
                        if store.config.searchEnabled {
                            Text("· 搜索").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                        }
                    }
                }
                Spacer()
                Button { showModelPicker = true } label: {
                    Image(systemName: "cpu").font(.subheadline).foregroundStyle(DSW.Alias.link)
                        .frame(width: 44, height: 44)
                }
                .popover(isPresented: $showModelPicker) {
                    VStack(alignment: .leading, spacing: DSW.Space.sm) {
                        Text("模型").font(DSW.TypeScale.headline)
                        ForEach(store.providers) { p in
                            if p.enabled {
                                ForEach(p.models) { m in
                                    Button {
                                        store.config.activeModelID = m.id; store.config.activeProviderID = p.id; store.save(); showModelPicker = false
                                    } label: {
                                        HStack {
                                            Text(m.label).font(DSW.TypeScale.body)
                                            Spacer()
                                            if store.config.activeModelID == m.id { Image(systemName: "checkmark").foregroundStyle(DSW.Alias.link) }
                                        }
                                    }
                                    .foregroundStyle(DSW.Alias.textPrimary)
                                }
                            }
                        }
                        Divider()
                        Toggle("深度思考", isOn: $store.config.thinkingEnabled)
                        Toggle("联网搜索", isOn: $store.config.searchEnabled)
                        Toggle("流式", isOn: $store.config.streamEnabled)
                    }
                    .padding()
                    .frame(width: 280)
                }
            }
            .padding(.horizontal, DSW.Space.md).padding(.top, DSW.Space.sm)

            // 消息流
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: DSW.Space.md) {
                        if let s = session {
                            ForEach(Array(s.messages.enumerated()), id: \.element.id) { i, m in
                                if m.role == .user {
                                    DSHUserBubble(text: m.text)
                                } else if m.role == .assistant {
                                    DSHAssistantBubble(message: m)
                                        .id(m.id)
                                }
                            }
                        }
                    }
                    .padding(.vertical, DSW.Space.md)
                }
                .onChange(of: session?.messages.count ?? 0) { _, _ in
                    if let last = session?.messages.last { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
                if let sid = session?.id, let mi = session?.messages.last?.id {
                    Color.clear.frame(height: 0).id("tail-\(sid)-\(mi)")
                }
            }

            // 输入栏（composer）
            VStack(spacing: DSW.Space.sm) {
                if case .toolRunning(let label) = runner.phase {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("正在调用 \(label)…").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textSecondary)
                        Spacer()
                    }
                }
                HStack(alignment: .bottom, spacing: DSW.Space.sm) {
                    TextField("发消息给 DeepSeek…", text: $input, axis: .vertical)
                        .font(DSW.TypeScale.body)
                        .lineLimit(1...6)
                        .focused($focused)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(DSW.Alias.fill, in: RoundedRectangle(cornerRadius: DSW.Radius.panel, style: .continuous))
                    if running {
                        Button { runner.cancel() } label: {
                            Image(systemName: "stop.fill")
                                .font(.body.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(DSW.Alias.danger, in: Circle())
                        }
                    } else {
                        Button { send() } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.semibold)).foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(input.trimmingCharacters(in: .whitespaces).isEmpty ? DSW.Alias.fill : DSW.Brand.blue, in: Circle())
                        }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(.horizontal, DSW.Space.md).padding(.vertical, DSW.Space.sm)
            .background(.bar)
        }
        .background(DSW.Alias.bg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var running: Bool {
        if case .streaming = runner.phase { return true }
        if case .toolRunning = runner.phase { return true }
        return false
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        if session == nil { store.newSession() }
        if store.sessions.first(where: { $0.id == store.activeSessionID })?.messages.isEmpty ?? true,
           store.config.autoTitle {
            store.bindMutate { $0.title = String(text.prefix(20)) }
        }
        runner.run(userText: text)
    }
}

import SwiftUI

// MARK: - Models（1:1 还原原版截图：DeepSeek 卡 + API key + Customized + Apply/Cancel + Add provider）
struct ModelsSettingsView: View {
    @EnvironmentObject var store: DSHStore
    @State private var newProviderSheet = false
    var body: some View {
        Form {
            if let official = store.providers.first(where: { $0.type == .deepseekOfficial }) {
                Section {
                    VStack(alignment: .leading, spacing: DSW.Space.md) {
                        HStack(spacing: 6) {
                            Text("DeepSeek").font(DSW.TypeScale.headline)
                            Text(official.id).font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                        }
                        VStack(align: .leading, spacing: 6) {
                            Text("API Key").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textSecondary)
                            SecureField("Enter your API key", text: Binding(
                                get: { official.apiKey },
                                set: { v in store.upsertProvider({ var p = official; p.apiKey = v; return p }()) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(DSW.TypeScale.body)
                        }
                        DisclosureGroup("Customized settings（自定义设置）") {
                            VStack(alignment: .leading, spacing: DSW.Space.sm) {
                                Text("Base URL").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textSecondary)
                                TextField("https://api.deepseek.com", text: Binding(
                                    get: { official.baseURL },
                                    set: { v in store.upsertProvider({ var p = official; p.baseURL = v; return p }()) }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        }
                        .font(DSW.TypeScale.caption)
                    }
                    .dswCard(DSW.Radius.xl)
                } header: {
                    Text("输入你的 API Key 以使用以下提供商的模型。")
                        .font(DSW.TypeScale.caption)
                        .foregroundStyle(DSW.Alias.textSecondary)
                        .textCase(nil)
                }
            }
            Section {
                Button { newProviderSheet = true } label: {
                    HStack { Spacer(); Label("+ Add model provider", systemImage: "plus").foregroundStyle(DSW.Alias.link); Spacer() }
                }
            }
            if !store.providers.filter({ $0.type == .custom }).isEmpty {
                Section("自定义提供商") {
                    ForEach(store.providers.filter { $0.type == .custom }) { p in
                        DisclosureGroup(p.label) {
                            VStack(alignment: .leading, spacing: DSW.Space.sm) {
                                HStack {
                                    Text("Key").font(DSW.TypeScale.caption)
                                    SecureField("sk-…", text: Binding(get: { p.apiKey }, set: { v in store.upsertProvider({ var q = p; q.apiKey = v; return q }()) })).textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Text("Base").font(DSW.TypeScale.caption)
                                    TextField("https://…", text: Binding(get: { p.baseURL }, set: { v in store.upsertProvider({ var q = p; q.baseURL = v; return q }()) })).textFieldStyle(.roundedBorder)
                                }
                                Toggle("启用", isOn: Binding(get: { p.enabled }, set: { v in store.upsertProvider({ var q = p; q.enabled = v; return q }()) }))
                                Button("删除提供商", role: .destructive) { store.providers.removeAll { $0.id == p.id }; store.save() }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("模型")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $newProviderSheet) { NewProviderSheet() }
    }
}

struct NewProviderSheet: View {
    @EnvironmentObject var store: DSHStore
    @Environment(\.dismiss) var dismiss
    @State private var label = ""
    @State private var base = ""
    @State private var key = ""
    @State private var models = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("提供商信息") {
                    TextField("名称（如 OpenAI）", text: $label)
                    TextField("Base URL（https://api.xxx.com）", text: $base)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                    SecureField("API Key", text: $key)
                    TextField("模型 ID（逗号分隔）", text: $models)
                        .textInputAutocapitalization(.never)
                }
                Text("兼容任何 OpenAI 格式 /chat/completions 的提供商即可使用（如 DeepSeek 官方网关、本地部署等）。")
                    .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
            }
            .navigationTitle("添加模型提供商")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        let list = models.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                        let id = "custom-" + UUID().uuidString.prefix(8)
                        let ms = list.isEmpty ? [DSHModel(id: "gpt-4o-mini", label: "Custom Model", providerID: id)] : list.map { DSHModel(id: $0, label: $0, providerID: id) }
                        store.upsertProvider(DSHProvider(id: id, label: label.isEmpty ? "自定义" : label, type: .custom, baseURL: base, apiKey: key, models: ms))
                        dismiss()
                    }
                    .disabled(label.isEmpty || base.isEmpty || key.isEmpty)
                }
            }
        }
    }
}

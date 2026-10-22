import SwiftUI

// Settings 框架（原版截图：左侧导航 General/Models/Built-in plugins/Agent presets → iOS NavigationStack 分页）
struct SettingsRootView: View {
    @EnvironmentObject var store: DSHStore
    var body: some View {
        List {
            Section {
                NavigationLink { GeneralSettingsView() } label: {
                    Label("通用", systemImage: "gearshape")
                }
                NavigationLink { ModelsSettingsView() } label: {
                    Label("模型", systemImage: "externaldrive.fill")
                }
                NavigationLink { PluginsSettingsView() } label: {
                    Label("内置插件", systemImage: "puzzlepiece.extension")
                }
                NavigationLink { PresetsSettingsView() } label: {
                    Label("Agent 预设", systemImage: "person.text.rectangle")
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("设置").font(DSW.TypeScale.title).foregroundStyle(DSW.Alias.textPrimary)
                    Text("DeepSeek Harness iOS · 原生移植").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                }
            }
            Section("更多") {
                NavigationLink { ScheduleSettingsView() } label: { Label("计划任务", systemImage: "clock") }
                NavigationLink { ExportSettingsView() } label: { Label("导入导出", systemImage: "square.and.arrow.up") }
                NavigationLink { AboutSettingsView() } label: { Label("关于", systemImage: "info.circle") }
            }
            Section("状态") {
                LabeledContent("当前模型", value: store.activeModel?.label ?? "未配置")
                LabeledContent("当前主题", value: "深色（原版默认）")
                LabeledContent("会话数", value: "\(store.sessions.count)")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSW.Alias.bg.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - General（原版 Settings → General）
struct GeneralSettingsView: View {
    @EnvironmentObject var store: DSHStore
    var body: some View {
        Form {
            Section("对话") {
                Toggle("自动生成标题", isOn: $store.config.autoTitle)
                Toggle("流式响应", isOn: $store.config.streamEnabled)
                Toggle("深度思考", isOn: $store.config.thinkingEnabled)
                Toggle("联网搜索", isOn: $store.config.searchEnabled)
                HStack {
                    Text("温度 \(store.config.temperature, specifier: "%.1f")")
                    Slider(value: $store.config.temperature, in: 0...1.5, step: 0.1)
                }
            }
            Section("沙盒") {
                LabeledContent("工作目录", value: "Documents/DSH")
                NavigationLink { SandboxBrowserView() } label: { Label("浏览沙盒文件", systemImage: "folder") }
            }
            Section("Agent") {
                Picker("启用预设", selection: $store.config.activePresetID) {
                    Text("无").tag(UUID?.none)
                    ForEach(store.presets) { Text($0.name).tag($0.id as UUID?) }
                }
            }
        }
        .navigationTitle("通用")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.config) { _, _ in store.save() }
    }
}

// MARK: - 沙盒文件浏览器
struct SandboxBrowserView: View {
    @State private var path = "."
    @State private var items: [String] = []
    private var url: URL { DSHStore.sandboxURL.appendingPathComponent(path) }
    var body: some View {
        List {
            if path != "." { Button("…上一层") { let p = path.components(separatedBy: "/").dropLast(2).joined(separator: "/"); path = p.isEmpty ? "." : p; load() } }
            ForEach(items, id: \.self) { n in
                let name = String(n.dropFirst(2))
                if n.hasPrefix("d ") {
                    Button { path = name; load() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "folder").foregroundStyle(DSW.Alias.link)
                            Text(name).foregroundStyle(DSW.Alias.textPrimary)
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "doc").foregroundStyle(DSW.Alias.textSecondary)
                        Text(name).foregroundStyle(DSW.Alias.textPrimary)
                    }
                }
            }
        }
        .navigationTitle("沙盒")
        .onAppear(perform: load)
    }
    private func load() {
        let fm = FileManager.default
        items = ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []).map {
            (( (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) ? "d  " : "f  ") + $0.lastPathComponent
        }
    }
}

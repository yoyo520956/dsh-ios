import SwiftUI

// MARK: - Built-in plugins（插件市场 iOS 化：分类 + 启用开关）
struct PluginsSettingsView: View {
    @EnvironmentObject var store: DSHStore
    private var groups: [(String, [DSHPlugin])] {
        let cats: [(String, String)] = [("agent", "Agent 能力"), ("tools", "工具"), ("memory", "记忆"), ("providers", "提供商"), ("workflow", "工作流")]
        return cats.compactMap { (id, name) in
            let items = store.plugins.filter { $0.category == id }
            return items.isEmpty ? nil : (name, items)
        }
    }
    var body: some View {
        List {
            ForEach(groups, id: \.0) { (name, items) in
                Section(name) {
                    ForEach(items) { p in
                        HStack(spacing: 12) {
                            Image(systemName: iconFor(p.category))
                                .font(.title3).foregroundStyle(DSW.Alias.link)
                                .frame(width: 36, height: 36)
                                .background(DSW.Alias.fill, in: RoundedRectangle(cornerRadius: DSW.Radius.tile, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).font(DSW.TypeScale.body)
                                Text(p.summary).font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary).lineLimit(2)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { p.enabled },
                                set: { v in
                                    if var q = store.plugins.first(where: { $0.id == p.id }) { q.enabled = v; store.upsertPlugin(q) }
                                })
                            )
                            .labelsHidden()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("内置插件")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func iconFor(_ c: String) -> String {
        switch c {
        case "agent": return "brain.head.profile"
        case "tools": return "wrench.and.screwdriver"
        case "memory": return "memorychip"
        case "providers": return "network"
        default: return "arrow.triangle.branch"
        }
    }
}

// MARK: - Agent presets
struct PresetsSettingsView: View {
    @EnvironmentObject var store: DSHStore
    @State private var editing: DSHAgentPreset?
    var body: some View {
        List {
            Section("当前预设：\(store.activePreset?.name ?? "未启用")") {
                Button { store.config.activePresetID = nil; store.save() } label: {
                    HStack { Text("无").foregroundStyle(DSW.Alias.textPrimary); Spacer(); if store.config.activePresetID == nil { Image(systemName: "checkmark").foregroundStyle(DSW.Alias.link) } }
                }
            }
            Section {
                ForEach(store.presets) { p in
                    Button {
                        store.config.activePresetID = p.id; store.save()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name).foregroundStyle(DSW.Alias.textPrimary)
                                Text(p.systemPrompt).font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary).lineLimit(2)
                            }
                            Spacer()
                            if store.config.activePresetID == p.id { Image(systemName: "checkmark").foregroundStyle(DSW.Alias.link) }
                        }
                    }
                    .swipeActions {
                        if !p.builtin {
                            Button(role: .destructive) { store.presets.removeAll { $0.id == p.id }; store.save() } label: { Label("删除", systemImage: "trash") }
                        }
                        Button { editing = p } label: { Label("编辑", systemImage: "pencil") }.tint(DSW.Alias.link)
                    }
                }
                Button { editing = DSHAgentPreset(name: "新预设", systemPrompt: "") } label: { Label("+ 新建预设", systemImage: "plus.circle") }
            }
        }
        .navigationTitle("Agent 预设")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { p in
            NavigationStack {
                PresetEditView(preset: p) { saved in
                    if let i = store.presets.firstIndex(where: { $0.id == saved.id }) { store.presets[i] = saved } else { store.presets.append(saved) }
                    store.save()
                }
            }
        }
    }
}

struct PresetEditView: View {
    @Environment(\.dismiss) var dismiss
    let preset: DSHAgentPreset
    let onSave: (DSHAgentPreset) -> Void
    @State private var name = ""
    @State private var prompt = ""
    var body: some View {
        Form {
            Section("名称") { TextField("预设名", text: $name) }
            Section("System Prompt") {
                TextEditor(text: $prompt).font(DSW.TypeScale.mono).frame(minHeight: 200)
            }
        }
        .navigationTitle("预设")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { onSave(DSHAgentPreset(id: preset.id, name: name, systemPrompt: prompt, toolIDs: preset.toolIDs, modelID: preset.modelID, builtin: false)); dismiss() } }
        }
        .onAppear { name = preset.name; prompt = preset.systemPrompt }
    }
}

// MARK: - Schedule（计划任务 UI + 本地通知）
struct ScheduleSettingsView: View {
    @EnvironmentObject var store: DSHStore
    var body: some View {
        List {
            ForEach($store.tasks) { t in
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(t.name.wrappedValue).font(DSW.TypeScale.body); Spacer(); Toggle("", isOn: t.enabled).labelsHidden() }
                    Text("每天 \(String(format: "%02d:%02d", t.hour.wrappedValue, t.minute.wrappedValue)) · \(t.prompt.wrappedValue.prefix(60))")
                        .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                }
                .swipeActions { Button(role: .destructive) { store.tasks.removeAll { $0.id == t.id }; store.save() } label: { Label("删除", systemImage: "trash") } }
            }
            Button { store.tasks.append(DSHScheduleTask(name: "新任务", prompt: "总结今日进展")); store.save() } label: { Label("+ 新建任务", systemImage: "plus.circle") }
        }
        .navigationTitle("计划任务")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Export
struct ExportSettingsView: View {
    @EnvironmentObject var store: DSHStore
    @State private var shareURL: URL?
    @State private var showShare = false
    var body: some View {
        Form {
            Section("导出当前会话") {
                Button("导出为 Markdown") { shareURL = exportMD(); showShare = true }
                Button("导出全部会话 JSON") { shareURL = exportJSON(); showShare = true }
            }
            Text("导出走系统分享面板（AirDrop/文件/微信）。")
                .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
        }
        .navigationTitle("导入导出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { if let u = shareURL { ShareSheet(items: [u]) } }
    }
    private func exportMD() -> URL {
        var md = "# 会话导出\n\n"
        for s in store.sessions {
            md += "## \(s.title)\n\n"
            for m in s.messages {
                if let r = m.reasoning, !r.isEmpty { md += "> 思考：\(r)\n\n" }
                md += m.role == .user ? "**我**：\(m.text)\n\n" : "**DSH**：\(m.text)\n\n"
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dsh-export-\(Int(Date().timeIntervalSince1970)).md")
        try? md.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    private func exportJSON() -> URL {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]; enc.dateEncodingStrategy = .iso8601
        let data = (try? enc.encode(store.sessions)) ?? Data()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dsh-sessions-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        return url
    }
}

// MARK: - About
struct AboutSettingsView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44)).foregroundStyle(DSW.Brand.blue)
                        Text("DeepSeek Harness").font(DSW.TypeScale.headline)
                        Text("iOS 原生移植版 v2.0.0").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                        Text("功能 1:1 全量 · 界面 iOS 化").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 24)
            }
            Section("诊断") {
                NavigationLink { DSHLogView() } label: { Label("运行日志", systemImage: "doc.text.magnifyingglass") }
            }
            Section("架构") {
                LabeledContent("界面", value: "SwiftUI + dsw 设计系统")
                LabeledContent("引擎", value: "DeepSeek API 原生直连")
                LabeledContent("工具", value: "file / bash / webfetch / search")
                LabeledContent("沙盒", value: "Documents/DSH")
            }
            Section("相对原版的差异") {
                Text("原版为 TypeScript monorepo（CLI + Web + Desktop + 54 插件包）。本 iOS 版为原生复刻：对话/工具循环/模型体系/插件市场/计划任务全量保留；Linux 层以 iOS 沙盒命令子集实现，桌面版专属 UI 由 iOS 惯例演绎。")
                    .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textSecondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ v: UIActivityViewController, context: Context) {}
}


// MARK: - 运行日志
struct DSHLogView: View {
    @State private var lines: [String] = []
    var body: some View {
        List(lines.reversed(), id: \.self) { l in
            Text(l).font(DSW.TypeScale.mono).foregroundStyle(DSW.Alias.textSecondary).textSelection(.enabled)
        }
        .navigationTitle("运行日志")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { lines = DSHLog.shared.snapshot() }
        .refreshable { lines = DSHLog.shared.snapshot() }
    }
}

import SwiftUI

/// 设置页：自定义 API（原版机制 $DSH_HOME/cordis.patch.yml 机器级 patch 层）
struct SettingsScreen: View {
    @EnvironmentObject var runtime: DshRuntime
    @AppStorage("dsh.api.baseURL") private var baseURL = ""
    @AppStorage("dsh.api.key") private var apiKey = ""
    @AppStorage("dsh.api.model") private var modelID = ""
    @State private var saving = false
    @State private var saveMsg: String?

    var body: some View {
        Form {
            Section("自定义 API（OpenAI 兼容）") {
                TextField("Base URL（如 https://api.example.com/v1）", text: $baseURL)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField("API Key", text: $apiKey)
                TextField("模型 ID（如 custom-model）", text: $modelID)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            Section {
                Button {
                    save()
                } label: {
                    if saving { ProgressView() } else { Text("保存并重启 dsh") }
                }
                .disabled(saving || baseURL.isEmpty || modelID.isEmpty)
                if let msg = saveMsg {
                    Text(msg).font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("写入原版配置层 $DSH_HOME/cordis.patch.yml（cordis.patch 机制，零改原版代码）。也可直接在 WebUI 原版设置里配置模型。")
            }

            Section("运行状态") {
                LabeledContent("阶段", value: phaseText)
                LabeledContent("端口", value: "\(runtime.port)")
                Button("重启 dsh web") { runtime.restartDsh() }
            }

            Section("关于") {
                LabeledContent("版本", value: "1.0.0 (20261022.01)")
                LabeledContent("原版", value: "deepseek-ai/deepseek-harness")
                LabeledContent("运行时", value: "iSH 内 node 跑 dsh web")
            }
        }
        .navigationTitle("设置")
    }

    private var phaseText: String {
        switch runtime.phase {
        case .idle: return "未启动"
        case .bootingIsh: return "iSH 启动中"
        case .startingDsh: return "dsh 启动中"
        case .serving: return "服务中 ✓"
        case .failed(let m): return "失败：\(m)"
        }
    }

    /// 生成 cordis.patch.yml 并经 iSH 写入（base64 转义无忧），完成后重启 dsh
    private func save() {
        saving = true
        saveMsg = nil
        let yml = """
        models:
          - provider: custom
            baseURL: \(baseURL)
            apiKey: \(apiKey)
            models:
              - id: "\(modelID)"
        """
        let b64 = Data(yml.utf8).base64EncodedString()
        let cmd = "mkdir -p \(DshRuntime.dshHome) && echo \(b64) | base64 -d > \(DshRuntime.dshHome)/cordis.patch.yml && wc -c \(DshRuntime.dshHome)/cordis.patch.yml"
        IshEngine.shared.startSession(
            command: ["/bin/sh", "-c", cmd],
            onOutput: { data in
                let s = String(data: data, encoding: .utf8) ?? ""
                Task { @MainActor in
                    if s.contains("cordis.patch.yml") { self.saveMsg = "已写入 ✓" }
                }
            },
            onExit: { _ in },
            done: { [weak runtime] _ in
                Task { @MainActor in
                    self.saving = false
                    self.saveMsg = (self.saveMsg == nil) ? "已写入 ✓（重启生效）" : self.saveMsg
                    runtime?.restartDsh()
                }
            }
        )
    }
}

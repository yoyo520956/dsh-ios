import SwiftUI

// 用户消息气泡（iOS 蓝惯例）
struct DSHUserBubble: View {
    let text: String
    var body: some View {
        HStack {
            Spacer(minLength: 40)
            Text(text)
                .font(DSW.TypeScale.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(DSW.Brand.blue, in: RoundedRectangle(cornerRadius: DSW.Radius.lg, style: .continuous))
                .textSelection(.enabled)
        }
        .padding(.horizontal, DSW.Space.md)
    }
}

// 深度思考折叠块（DeepSeek reasoning）
struct DSHThinkingBlock: View {
    let text: String
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: DSW.Space.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundStyle(DSW.Alias.textTertiary)
                    Image(systemName: "brain").font(.caption).foregroundStyle(DSW.Alias.textTertiary)
                    Text("深度思考 \(text.count) 字").font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                }
            }
            .buttonStyle(.plain)
            if expanded {
                Text(text)
                    .font(DSW.TypeScale.callout).foregroundStyle(DSW.Alias.textSecondary)
                    .textSelection(.enabled)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DSW.Space.sm)
        .background(DSW.Alias.surfaceSunken, in: RoundedRectangle(cornerRadius: DSW.Radius.md, style: .continuous))
    }
}

// 工具调用卡片
struct DSHToolCallCard: View {
    let call: DSHToolCall
    @State private var expanded = false
    private var icon: String {
        switch call.name {
        case "file": return "doc.text"
        case "bash": return "terminal"
        case "webfetch": return "globe"
        case "search": return "magnifyingglass"
        default: return "wrench"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(DSW.Alias.link)
                Text(call.name + " 工具").font(DSW.TypeScale.caption).fontWeight(.medium)
                Spacer()
                Circle()
                    .fill(call.status == .done ? DSW.Alias.success : DSW.Alias.warn)
                    .frame(width: 6, height: 6)
            }
            if expanded || call.status == .done {
                Group {
                    Text(call.arguments.count > 600 ? String(call.arguments.prefix(600)) + "…" : call.arguments)
                        .font(DSW.TypeScale.mono).foregroundStyle(DSW.Alias.textTertiary)
                    if let r = call.result {
                        Divider().opacity(0.4)
                        Text(r.count > 1200 ? String(r.prefix(1200)) + "…" : r)
                            .font(DSW.TypeScale.mono).foregroundStyle(DSW.Alias.textSecondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(DSW.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSW.Alias.surface, in: RoundedRectangle(cornerRadius: DSW.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DSW.Radius.md, style: .continuous).stroke(DSW.Alias.hairline, lineWidth: 0.5))
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }
    }
}

// assistant 消息
struct DSHAssistantBubble: View {
    let message: DSHMessage
    var body: some View {
        VStack(alignment: .leading, spacing: DSW.Space.sm) {
            if let r = message.reasoning, !r.isEmpty { DSHThinkingBlock(text: r) }
            if !message.text.isEmpty {
                Text(message.text)
                    .font(DSW.TypeScale.body).foregroundStyle(DSW.Alias.textPrimary)
                    .textSelection(.enabled)
            }
            if let calls = message.toolCalls, !calls.isEmpty {
                ForEach(calls) { DSHToolCallCard(call: $0) }
            }
            if let err = message.streamError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.danger)
            }
        }
        .padding(.horizontal, DSW.Space.md)
    }
}

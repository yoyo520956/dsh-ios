import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var store: DSHStore
    @State private var editing: DSHSession?
    @State private var renaming = ""
    var body: some View {
        List {
            Section {
                Button {
                    _ = store.newSession()
                } label: { Label("新建会话", systemImage: "plus.circle.fill").foregroundStyle(DSW.Alias.link) }
            }
            Section("历史会话 \(store.sessions.count)") {
                ForEach(store.sessions) { s in
                    Button {
                        store.activeSessionID = s.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).foregroundStyle(s.id == store.activeSessionID ? DSW.Alias.link : DSW.Alias.textPrimary).lineLimit(1)
                                Text("\(s.messages.count) 条消息 · \(s.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(DSW.TypeScale.caption).foregroundStyle(DSW.Alias.textTertiary)
                            }
                            Spacer()
                            if s.id == store.activeSessionID { Image(systemName: "checkmark").foregroundStyle(DSW.Alias.link) }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { store.deleteSession(s.id) } label: { Label("删除", systemImage: "trash") }
                        Button { renaming = s.title; editing = s } label: { Label("改名", systemImage: "pencil") }.tint(DSW.Alias.link)
                    }
                }
            }
        }
        .navigationTitle("会话")
        .alert("重命名", isPresented: .init(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("标题", text: $renaming)
            Button("保存") { if let e = editing { store.renameSession(e.id, title: renaming) } }
            Button("取消", role: .cancel) {}
        }
    }
}

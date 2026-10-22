import SwiftUI

@main
public struct DSHApp: App {
    @StateObject private var store = DSHStore.shared
    @StateObject private var runner = DSHAgentRunner()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            DSHRootView()
                .environmentObject(store)
                .environmentObject(runner)
                .preferredColorScheme(.dark)   // 原版默认深色
                .onAppear {
                    if store.activeSessionID == nil { store.newSession() }
                    store.scheduler.start()
                }
                .onChange(of: store.autoRunPrompt) { newPrompt in
                    if let p = newPrompt, !p.isEmpty {
                        store.autoRunPrompt = nil
                        runner.run(userText: p)
                    }
                }
        }
    }
}

struct DSHRootView: View {
    @EnvironmentObject var store: DSHStore
    var body: some View {
        TabView {
            NavigationStack { ChatView() }
                .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right.fill") }
            NavigationStack { SessionsView() }
                .tabItem { Label("会话", systemImage: "list.bullet.rectangle") }
            NavigationStack { SettingsRootView() }
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(DSW.Brand.blue)
    }
}

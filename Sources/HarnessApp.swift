import SwiftUI

@main
struct HarnessApp: App {
    @StateObject private var runtime = DshRuntime.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    DshWebView()
                        .tabItem { Label("Harness", systemImage: "terminal") }
                }
                NavigationStack {
                    TerminalView()
                        .tabItem { Label("终端", systemImage: "chevron.left.forwardslash.chevron.right") }
                }
                NavigationStack {
                    SettingsScreen()
                        .tabItem { Label("设置", systemImage: "gearshape") }
                }
            }
            .environmentObject(runtime)
            .environmentObject(IshEngine.shared)
            .environmentObject(HarnessTheme.shared)
            .onAppear { runtime.start() }
        }
    }
}

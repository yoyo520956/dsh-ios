import SwiftUI

@main
struct HarnessApp: App {
    @StateObject private var runtime = DshRuntime.shared

    var body: some Scene {
        WindowGroup {
            TabView {
                DshWebView()
                    .tabItem { Label("Harness", systemImage: "terminal") }
                TerminalView()
                    .tabItem { Label("终端", systemImage: "chevron.left.forwardslash.chevron.right") }
                SettingsScreen()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .environmentObject(runtime)
            .onAppear { runtime.start() }
        }
    }
}

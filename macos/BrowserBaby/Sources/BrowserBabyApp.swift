import SwiftUI

@main
struct BrowserBabyApp: App {
    @StateObject private var store = BrowserStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .commands {
            CommandMenu("Tabs") {
                Button("New Tab") {
                    store.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    store.closeSelectedTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(store.selectedTabID == nil)

                Divider()

                Button("Toggle Favorite") {
                    store.toggleFavoriteForSelection()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .disabled(store.selectedTabID == nil)

                Button("Toggle Pin") {
                    store.togglePinnedForSelection()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(store.selectedTabID == nil)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1320, height: 840)
    }
}

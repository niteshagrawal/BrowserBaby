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

                Button("New Private Tab") {
                    store.addTab(isPrivate: true)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Button("Reopen Closed Tab") {
                    store.reopenLastClosedTab()
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])

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

            CommandMenu("Navigate") {
                Button("Back") {
                    store.goBackSelectedTab()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!store.canGoBack)

                Button("Forward") {
                    store.goForwardSelectedTab()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!store.canGoForward)

                Button("Reload") {
                    store.reloadSelectedTab()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.selectedTabID == nil)
            }

            CommandMenu("Compatibility") {
                Button("Run Top Sites Suite") {
                    store.runCompatibilitySuite()
                }
            }

            CommandMenu("Downloads") {
                Button("Open Downloads Folder") {
                    store.openDownloadsFolder()
                }

                Button("Clear Finished Downloads") {
                    store.clearFinishedDownloads()
                }
                .disabled(!store.downloads.contains(where: { $0.state == .finished }))
            }

            CommandMenu("Permissions") {
                ForEach(PermissionKind.allCases) { kind in
                    Button("\(kind.displayName): \((store.permissionStates[kind] ?? .ask).rawValue.capitalized)") {
                        store.cyclePermissionState(kind)
                    }
                }
                Divider()
                Button("Reset Permissions") {
                    store.resetPermissionStates()
                }
            }

            CommandMenu("Privacy") {
                Button(store.defaultPrivateModeEnabled ? "Disable Default Private Mode" : "Enable Default Private Mode") {
                    store.toggleDefaultPrivateMode()
                }

                Button("Clear Regular Browsing Data") {
                    store.clearRegularBrowsingData()
                }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1320, height: 840)
    }
}

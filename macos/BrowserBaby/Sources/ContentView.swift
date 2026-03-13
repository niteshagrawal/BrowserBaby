import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BrowserStore

    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedTabID) {
                Section("Favorites") {
                    ForEach(store.tabs.filter(\.isFavorite)) { tabRow($0) }
                }

                Section("Pinned") {
                    ForEach(store.tabs.filter(\.isPinned)) { tabRow($0) }
                }

                ForEach(store.folders) { folder in
                    Section(folder.name) {
                        ForEach(store.tabs.filter { $0.folderID == folder.id }) { tab in
                            tabRow(tab, folderID: folder.id)
                        }
                    }
                }

                Section("All Tabs") {
                    ForEach(store.tabs.filter { $0.folderID == nil && !$0.isFavorite && !$0.isPinned }) { tabRow($0) }
                }
            }
            .toolbar {
                Button("New Tab") { store.addTab() }
            }
            .frame(minWidth: 280)
        } detail: {
            if let selectedID = store.selectedTabID {
                if let selectedTab = store.tabs.first(where: { $0.id == selectedID }) {
                    WebViewContainer(webView: store.webView(for: selectedID))
                        .toolbar {
                            Picker("Engine", selection: Binding(
                                get: { selectedTab.engine },
                                set: { store.setEngine($0, for: selectedID) }
                            )) {
                                ForEach(BrowserEngine.allCases) { engine in
                                    Text(engine.displayName).tag(engine)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                } else {
                    Text("Select a tab")
                }
            } else {
                Text("Create your first tab")
            }
        }
    }

    @ViewBuilder
    private func tabRow(_ tab: BrowserTab, folderID: UUID? = nil) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.body)
                Text(tab.currentURL.host() ?? tab.currentURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if tab.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            if tab.isPinned { Image(systemName: "pin.fill") }
        }
        .contextMenu {
            Button(tab.isFavorite ? "Unfavorite" : "Favorite") { store.toggleFavorite(tab.id) }
            Button(tab.isPinned ? "Unpin" : "Pin") { store.togglePinned(tab.id) }
            if let folderID {
                Button("Toggle folder pin") { store.toggleFolderPin(tabID: tab.id, folderID: folderID) }
            }
            Button("Close Tab") { store.closeTab(tab.id) }
        }
        .tag(tab.id)
    }
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BrowserStore

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTabID },
            set: { newValue in
                guard let id = newValue else { return }
                store.selectTab(id)
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selectionBinding) {
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
            .frame(minWidth: 300)
        } detail: {
            if let selectedID = store.selectedTabID,
               let selectedTab = store.tabs.first(where: { $0.id == selectedID }),
               let webView = store.activeWebView() {
                WebViewContainer(webView: webView)
                    .toolbar {
                        Toggle(isOn: Binding(
                            get: { store.defaultPrivateModeEnabled },
                            set: { store.defaultPrivateModeEnabled = $0 }
                        )) {
                            Label("Default Private", systemImage: "eye.slash")
                        }
                        .toggleStyle(.checkbox)

                        if selectedTab.isPrivate {
                            Label("Private Tab", systemImage: "eye.slash.fill")
                                .foregroundStyle(.purple)
                        }

                        Button("Clear Data") {
                            store.clearRegularBrowsingData()
                        }

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
                ContentUnavailableView("No Tab Selected", systemImage: "globe")
            }
        }
    }

    @ViewBuilder
    private func tabRow(_ tab: BrowserTab, folderID: UUID? = nil) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title)
                    .font(.body)
                    .lineLimit(1)
                Text(tab.currentURL.host() ?? tab.currentURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if tab.isPrivate { Image(systemName: "eye.slash") }
            if tab.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            if tab.isPinned { Image(systemName: "pin.fill") }
        }
        .contextMenu {
            Button(tab.isFavorite ? "Unfavorite" : "Favorite") { store.toggleFavorite(tab.id) }
            Button(tab.isPinned ? "Unpin" : "Pin") { store.togglePinned(tab.id) }
            if let folderID { Button("Toggle Folder Pin") { store.toggleFolderPin(tabID: tab.id, folderID: folderID) } }
            Divider()
            Button("Close Tab") { store.closeTab(tab.id) }
        }
        .tag(tab.id)
    }
}

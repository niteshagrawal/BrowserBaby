import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BrowserStore
    @State private var addressInput = ""
    @State private var findInput = ""

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

                Section("Downloads") {
                    if store.downloads.isEmpty {
                        Text("No downloads yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.downloads.prefix(5)) { item in
                            downloadRow(item)
                        }
                    }
                }

                Section("Compatibility") {
                    Button("Run Top Sites Suite") {
                        store.runCompatibilitySuite()
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
                    .overlay(alignment: .top) {
                        if let warning = store.lastNavigationWarning {
                            Text(warning)
                                .font(.caption)
                                .padding(8)
                                .background(.red.opacity(0.9), in: Capsule())
                                .foregroundStyle(.white)
                                .padding(.top, 8)
                        }
                    }
                    .onAppear {
                        addressInput = selectedTab.currentURL.absoluteString
                    }
                    .onChange(of: selectedID) { _ in
                        addressInput = selectedTab.currentURL.absoluteString
                        findInput = ""
                    }
                    .onChange(of: selectedTab.currentURL) { newURL in
                        addressInput = newURL.absoluteString
                    }
                    .toolbar {
                        Button {
                            store.goBackSelectedTab()
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                        .disabled(!store.canGoBack)

                        Button {
                            store.goForwardSelectedTab()
                        } label: {
                            Label("Forward", systemImage: "chevron.forward")
                        }
                        .disabled(!store.canGoForward)

                        Button {
                            store.reloadSelectedTab()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }

                        TextField("Search or enter website name", text: $addressInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 360)
                            .onSubmit {
                                store.navigateSelectedTab(input: addressInput)
                            }

                        TextField("Find in page", text: $findInput)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .onSubmit {
                                store.findInSelectedTab(findInput)
                            }

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

                        Menu("Permissions") {
                            ForEach(PermissionKind.allCases) { kind in
                                Button("\(kind.displayName): \((store.permissionStates[kind] ?? .ask).rawValue.capitalized)") {
                                    store.cyclePermissionState(kind)
                                }
                            }
                            Divider()
                            Button("Reset") { store.resetPermissionStates() }
                        }
                        Button("Clear Data") {
                            store.clearRegularBrowsingData()
                        }

                        Button("Downloads Folder") {
                            store.openDownloadsFolder()
                        }

                        Button("Clear Finished") {
                            store.clearFinishedDownloads()
                        }
                        .disabled(!store.downloads.contains(where: { $0.state == .finished }))

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
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No Tab Selected")
                        .font(.headline)
                    Text("Open a tab or choose one from the sidebar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }



    @ViewBuilder
    private func downloadRow(_ item: DownloadItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: item.state == .finished ? "arrow.down.doc.fill" : (item.state == .failed ? "exclamationmark.triangle.fill" : "arrow.down.circle"))
                .foregroundStyle(item.state == .failed ? .red : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .lineLimit(1)
                Text(item.state.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if item.state == .finished {
                Button("Open") { store.openDownload(item.id) }
                    .buttonStyle(.borderless)
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

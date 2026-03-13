import Foundation
import WebKit

@MainActor
final class BrowserStore: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var folders: [TabFolder] = []
    @Published var selectedTabID: UUID?
    @Published var defaultEngine: BrowserEngine = .webkit

    private var webViews: [UUID: WKWebView] = [:]

    init() {
        let folder = TabFolder(name: "Work")
        folders = [folder]
        let sampleTab = BrowserTab(title: "BrowserBaby", baseURL: URL(string: "https://example.com")!, folderID: folder.id)
        tabs = [sampleTab]
        selectedTabID = sampleTab.id
    }

    func addTab(in folderID: UUID? = nil, url: URL = URL(string: "https://example.com")!) {
        let tab = BrowserTab(title: "New Tab", baseURL: url, engine: defaultEngine, folderID: folderID)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func toggleFavorite(_ tabID: UUID) {
        updateTab(tabID) { $0.isFavorite.toggle() }
    }

    func togglePinned(_ tabID: UUID) {
        updateTab(tabID) { $0.isPinned.toggle() }
    }

    func toggleFolderPin(tabID: UUID, folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        if folders[index].pinnedTabIDs.contains(tabID) {
            folders[index].pinnedTabIDs.remove(tabID)
        } else {
            folders[index].pinnedTabIDs.insert(tabID)
        }
    }

    func closeTab(_ tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }

        if let folderID = tab.folderID,
           let folder = folders.first(where: { $0.id == folderID }),
           folder.pinnedTabIDs.contains(tabID) {
            resetTab(tabID)
            return
        }

        if tab.isPinned {
            resetTab(tabID)
            return
        }

        tabs.removeAll { $0.id == tabID }
        webViews[tabID] = nil
        selectedTabID = tabs.first?.id
    }

    func resetTab(_ tabID: UUID) {
        updateTab(tabID) { tab in
            tab.currentURL = tab.baseURL
        }
        webViews[tabID]?.load(URLRequest(url: tabs.first(where: { $0.id == tabID })?.baseURL ?? URL(string: "https://example.com")!))
    }

    func setEngine(_ engine: BrowserEngine, for tabID: UUID) {
        updateTab(tabID) { $0.engine = engine }
        if engine == .chromium {
            // Placeholder fallback until Chromium backend is integrated.
            updateTab(tabID) { $0.engine = .webkit }
        }
    }

    func webView(for tabID: UUID) -> WKWebView {
        if let existing = webViews[tabID] {
            return existing
        }

        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        if let tab = tabs.first(where: { $0.id == tabID }) {
            view.load(URLRequest(url: tab.currentURL))
        }
        webViews[tabID] = view
        return view
    }

    private func updateTab(_ tabID: UUID, update: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        update(&tabs[index])
    }
}

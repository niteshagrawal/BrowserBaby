import Foundation
import WebKit

@MainActor
final class BrowserStore: NSObject, ObservableObject {
    enum TabCloseOutcome: Equatable {
        case closed
        case resetPinned
        case ignored
    }

    @Published var tabs: [BrowserTab] = [] {
        didSet { schedulePersistSession() }
    }
    @Published var folders: [TabFolder] = [] {
        didSet { schedulePersistSession() }
    }
    @Published var selectedTabID: UUID? {
        didSet { schedulePersistSession() }
    }
    @Published var defaultEngine: BrowserEngine = .webkit {
        didSet { schedulePersistSession() }
    }
    @Published var defaultPrivateModeEnabled: Bool = false {
        didSet { schedulePersistSession() }
    }

    private let webViewPool = WebViewPool(maxLiveViews: 6)
    private var tabIDByWebView: [ObjectIdentifier: UUID] = [:]
    private let sessionPersistence = SessionPersistence()
    private var persistenceTask: Task<Void, Never>?

    init(seedData: Bool = true) {
        super.init()

        if restoreSession() {
            return
        }

        guard seedData else { return }
        let folder = TabFolder(name: "Work")
        folders = [folder]
        let sampleTab = BrowserTab(title: "BrowserBaby", baseURL: URL(string: "https://example.com")!, folderID: folder.id)
        tabs = [sampleTab]
        selectedTabID = sampleTab.id
    }

    deinit {
        persistenceTask?.cancel()
    }

    func addTab(in folderID: UUID? = nil, url: URL = URL(string: "https://example.com")!, isPrivate: Bool? = nil) {
        let tab = BrowserTab(title: "New Tab", baseURL: url, isPrivate: isPrivate ?? defaultPrivateModeEnabled, engine: defaultEngine, folderID: folderID)
        tabs.append(tab)
        selectTab(tab.id)
    }

    func closeSelectedTab() {
        guard let selectedTabID else { return }
        _ = closeTab(selectedTabID)
    }

    func selectTab(_ tabID: UUID) {
        updateTab(tabID) { $0.lastAccessedAt = .now }
        selectedTabID = tabID
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        _ = webView(for: tab.id, initialURL: tab.currentURL)
        trimInactiveTabs()
    }

    func toggleFavorite(_ tabID: UUID) { updateTab(tabID) { $0.isFavorite.toggle() } }
    func togglePinned(_ tabID: UUID) { updateTab(tabID) { $0.isPinned.toggle() } }

    func toggleFavoriteForSelection() {
        guard let selectedTabID else { return }
        toggleFavorite(selectedTabID)
    }

    func togglePinnedForSelection() {
        guard let selectedTabID else { return }
        togglePinned(selectedTabID)
    }

    func toggleFolderPin(tabID: UUID, folderID: UUID) {
        guard let index = folders.firstIndex(where: { $0.id == folderID }) else { return }
        if folders[index].pinnedTabIDs.contains(tabID) {
            folders[index].pinnedTabIDs.remove(tabID)
        } else {
            folders[index].pinnedTabIDs.insert(tabID)
        }
    }

    @discardableResult
    func closeTab(_ tabID: UUID) -> TabCloseOutcome {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return .ignored }

        if isFolderPinned(tabID: tabID, folderID: tab.folderID) || tab.isPinned {
            resetTab(tabID)
            return .resetPinned
        }

        tabs.removeAll { $0.id == tabID }
        webViewPool.release(tabID: tabID)

        if selectedTabID == tabID {
            selectedTabID = tabs.sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt }).first?.id
        }
        trimInactiveTabs()
        return .closed
    }

    func resetTab(_ tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        updateTab(tabID) {
            $0.currentURL = tab.baseURL
            $0.lastAccessedAt = .now
        }

        if let webView = webViewPool.existingWebView(for: tabID) {
            webView.stopLoading()
            webView.load(URLRequest(url: tab.baseURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30))
        }
    }

    func setEngine(_ engine: BrowserEngine, for tabID: UUID) {
        updateTab(tabID) { $0.engine = engine == .chromium ? .webkit : engine }
    }

    func toggleDefaultPrivateMode() {
        defaultPrivateModeEnabled.toggle()
    }

    func clearRegularBrowsingData() {
        let allDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: allDataTypes, modifiedSince: .distantPast) {}
    }

    func activeWebView() -> WKWebView? {
        guard let selectedTabID, let tab = tabs.first(where: { $0.id == selectedTabID }) else {
            return nil
        }
        return webView(for: selectedTabID, initialURL: tab.currentURL)
    }

    private func schedulePersistSession() {
        persistenceTask?.cancel()
        let snapshot = BrowserSessionSnapshot(
            tabs: tabs,
            folders: folders,
            selectedTabID: selectedTabID,
            defaultEngine: defaultEngine,
            defaultPrivateModeEnabled: defaultPrivateModeEnabled
        )
        persistenceTask = Task { [sessionPersistence] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            sessionPersistence.save(snapshot: snapshot)
        }
    }

    private func restoreSession() -> Bool {
        guard let snapshot = sessionPersistence.load(), !snapshot.tabs.isEmpty else {
            return false
        }

        tabs = snapshot.tabs
        folders = snapshot.folders
        defaultEngine = snapshot.defaultEngine
        defaultPrivateModeEnabled = snapshot.defaultPrivateModeEnabled

        if let selectedTabID = snapshot.selectedTabID,
           tabs.contains(where: { $0.id == selectedTabID }) {
            self.selectedTabID = selectedTabID
        } else {
            self.selectedTabID = tabs.max(by: { $0.lastAccessedAt < $1.lastAccessedAt })?.id
        }

        return true
    }

    private func webView(for tabID: UUID, initialURL: URL) -> WKWebView {
        let isPrivate = tabs.first(where: { $0.id == tabID })?.isPrivate ?? false
        let webView = webViewPool.webView(for: tabID, initialURL: initialURL, isPrivate: isPrivate, navigationDelegate: self, uiDelegate: self)
        tabIDByWebView[ObjectIdentifier(webView)] = tabID
        return webView
    }

    private func trimInactiveTabs() {
        var protectedIDs: Set<UUID> = Set(tabs.filter(\.isPinned).map(\.id))
        if let selectedTabID {
            protectedIDs.insert(selectedTabID)
        }
        webViewPool.trimIfNeeded(protectedTabIDs: protectedIDs)
    }

    private func isFolderPinned(tabID: UUID, folderID: UUID?) -> Bool {
        guard let folderID, let folder = folders.first(where: { $0.id == folderID }) else { return false }
        return folder.pinnedTabIDs.contains(tabID)
    }

    private func updateTab(_ tabID: UUID, update: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        update(&tabs[index])
    }
}

extension BrowserStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let webViewID = ObjectIdentifier(webView)
        guard let tabID = tabIDByWebView[webViewID] else { return }

        updateTab(tabID) { tab in
            if let url = webView.url {
                tab.currentURL = url
            }
            let pageTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let pageTitle, !pageTitle.isEmpty {
                tab.title = pageTitle
            }
            tab.lastAccessedAt = .now
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension BrowserStore: WKUIDelegate {}

import AppKit
import Foundation
import WebKit

@MainActor
final class BrowserStore: NSObject, ObservableObject {
    enum TabCloseOutcome: Equatable {
        case closed
        case resetPinned
        case ignored
    }

    struct CompatibilitySite: Identifiable, Hashable, Codable {
        let id: UUID
        var name: String
        var url: URL

        init(id: UUID = UUID(), name: String, url: URL) {
            self.id = id
            self.name = name
            self.url = url
        }
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
    @Published var permissionStates: [PermissionKind: PermissionState] = BrowserStore.defaultPermissionStates() {
        didSet { schedulePersistSession() }
    }
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var downloads: [DownloadItem] = []
    @Published var lastNavigationWarning: String?

    private(set) var compatibilitySites: [CompatibilitySite] = [
        CompatibilitySite(name: "Google Docs", url: URL(string: "https://docs.google.com")!),
        CompatibilitySite(name: "Gmail", url: URL(string: "https://mail.google.com")!),
        CompatibilitySite(name: "Slack", url: URL(string: "https://app.slack.com")!),
        CompatibilitySite(name: "GitHub", url: URL(string: "https://github.com")!),
        CompatibilitySite(name: "YouTube", url: URL(string: "https://www.youtube.com")!)
    ]

    private let webViewPool = WebViewPool(maxLiveViews: 6)
    private var tabIDByWebView: [ObjectIdentifier: UUID] = [:]
    private let sessionPersistence = SessionPersistence()
    private var persistenceTask: Task<Void, Never>?
    private var downloadIDByObjectID: [ObjectIdentifier: UUID] = [:]
    private var recentlyClosedTabs: [BrowserTab] = []
    private var terminationCountByTabID: [UUID: Int] = [:]

    init(seedData: Bool = true) {
        super.init()

        if restoreSession() {
            return
        }

        guard seedData else { return }
        let folder = TabFolder(name: "Work")
        folders = [folder]
        let sampleTab = BrowserTab(
            title: "BrowserBaby",
            baseURL: URL(string: "https://example.com")!,
            folderID: folder.id
        )
        tabs = [sampleTab]
        selectedTabID = sampleTab.id
    }

    deinit {
        persistenceTask?.cancel()
    }

    func addTab(in folderID: UUID? = nil, url: URL = URL(string: "https://example.com")!, isPrivate: Bool? = nil) {
        let tab = BrowserTab(
            title: "New Tab",
            baseURL: url,
            isPrivate: isPrivate ?? defaultPrivateModeEnabled,
            engine: defaultEngine,
            folderID: folderID
        )
        tabs.append(tab)
        selectTab(tab.id)
    }

    func reopenLastClosedTab() {
        guard let tab = recentlyClosedTabs.first else { return }
        recentlyClosedTabs.removeFirst()
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
        if let webView = webViewPool.existingWebView(for: tabID) {
            updateNavigationState(for: webView)
        } else {
            _ = webView(for: tab.id, initialURL: tab.currentURL)
        }
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

    func setPermissionState(_ state: PermissionState, for kind: PermissionKind) {
        permissionStates[kind] = state
    }

    func cyclePermissionState(_ kind: PermissionKind) {
        var state = permissionStates[kind] ?? .ask
        state.cycle()
        permissionStates[kind] = state
    }

    func resetPermissionStates() {
        permissionStates = Self.defaultPermissionStates()
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

        recentlyClosedTabs.insert(tab, at: 0)
        recentlyClosedTabs = Array(recentlyClosedTabs.prefix(20))
        tabs.removeAll { $0.id == tabID }
        webViewPool.release(tabID: tabID)
        terminationCountByTabID.removeValue(forKey: tabID)

        if selectedTabID == tabID {
            selectedTabID = tabs.sorted(by: { $0.lastAccessedAt > $1.lastAccessedAt }).first?.id
        }
        trimInactiveTabs()
        return .closed
    }

    func resetTab(_ tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        terminationCountByTabID[tabID] = 0
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

    func navigateSelectedTab(input: String) {
        guard let selectedTabID else { return }
        navigate(tabID: selectedTabID, input: input)
    }

    func navigate(tabID: UUID, input: String) {
        guard let url = Self.resolveNavigationURL(from: input) else {
            lastNavigationWarning = "Blocked unsafe or invalid URL."
            return
        }
        lastNavigationWarning = nil
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }

        updateTab(tabID) {
            $0.currentURL = url
            $0.baseURL = $0.isPinned ? $0.baseURL : url
            $0.lastAccessedAt = .now
        }

        let webView = webView(for: tab.id, initialURL: tab.currentURL)
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 30))
        updateNavigationState(for: webView)
    }

    func runCompatibilitySuite() {
        guard !compatibilitySites.isEmpty else { return }

        let folderID: UUID
        if let existing = folders.first(where: { $0.name == "Compatibility QA" })?.id {
            folderID = existing
        } else {
            let folder = TabFolder(name: "Compatibility QA")
            folders.append(folder)
            folderID = folder.id
        }

        for site in compatibilitySites {
            addTab(in: folderID, url: site.url)
        }
    }

    func goBackSelectedTab() {
        guard let webView = activeWebView(), webView.canGoBack else { return }
        webView.goBack()
        updateNavigationState(for: webView)
    }

    func goForwardSelectedTab() {
        guard let webView = activeWebView(), webView.canGoForward else { return }
        webView.goForward()
        updateNavigationState(for: webView)
    }

    func reloadSelectedTab() {
        guard let webView = activeWebView() else { return }
        webView.reload()
    }

    func findInSelectedTab(_ query: String) {
        guard let webView = activeWebView() else { return }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        let escaped = trimmedQuery
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.find(\"\(escaped)\", false, false, true, false, false, false);"
        webView.evaluateJavaScript(js)
    }

    func openDownload(_ itemID: UUID) {
        guard let item = downloads.first(where: { $0.id == itemID }),
              let destinationURL = item.destinationURL,
              item.state == .finished else { return }
        NSWorkspace.shared.open(destinationURL)
    }

    func openDownloadsFolder() {
        NSWorkspace.shared.open(Self.downloadsDirectory())
    }

    func clearFinishedDownloads() {
        downloads.removeAll { $0.state == .finished }
    }

    static func resolveNavigationURL(from rawInput: String) -> URL? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), let scheme = directURL.scheme, !scheme.isEmpty {
            let normalized = scheme.lowercased()
            guard normalized == "http" || normalized == "https" else { return nil }
            return directURL
        }

        if trimmed.contains(" ") {
            let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            return URL(string: "https://duckduckgo.com/?q=\(query)")
        }

        if trimmed.contains(".") {
            return URL(string: "https://\(trimmed)")
        }

        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://duckduckgo.com/?q=\(query)")
    }

    static func downloadsDirectory() -> URL {
        let fileManager = FileManager.default
        let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let folder = downloads.appendingPathComponent("BrowserBaby", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func safeDownloadURL(for suggestedFilename: String) -> URL {
        let sanitized = suggestedFilename
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
        let filename = sanitized.isEmpty ? "download.bin" : sanitized
        return downloadsDirectory().appendingPathComponent(filename)
    }

    private static func defaultPermissionStates() -> [PermissionKind: PermissionState] {
        Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0, .ask) })
    }

    private func schedulePersistSession() {
        persistenceTask?.cancel()
        let snapshot = BrowserSessionSnapshot(
            tabs: tabs,
            folders: folders,
            selectedTabID: selectedTabID,
            defaultEngine: defaultEngine,
            defaultPrivateModeEnabled: defaultPrivateModeEnabled,
            permissionStates: permissionStates,
            recentlyClosedTabs: recentlyClosedTabs
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
        permissionStates = snapshot.permissionStates
        recentlyClosedTabs = snapshot.recentlyClosedTabs

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
        let webView = webViewPool.webView(
            for: tabID,
            initialURL: initialURL,
            isPrivate: isPrivate,
            navigationDelegate: self,
            uiDelegate: self
        )
        tabIDByWebView[ObjectIdentifier(webView)] = tabID
        updateNavigationState(for: webView)
        return webView
    }

    private func trimInactiveTabs() {
        var protectedIDs: Set<UUID> = Set(tabs.filter(\.isPinned).map(\.id))
        if let selectedTabID {
            protectedIDs.insert(selectedTabID)
        }
        webViewPool.trimIfNeeded(protectedTabIDs: protectedIDs)
    }

    private func updateNavigationState(for webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    private func isFolderPinned(tabID: UUID, folderID: UUID?) -> Bool {
        guard let folderID, let folder = folders.first(where: { $0.id == folderID }) else { return false }
        return folder.pinnedTabIDs.contains(tabID)
    }

    private func updateTab(_ tabID: UUID, update: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        update(&tabs[index])
    }

    private func startTracking(download: WKDownload, response: URLResponse?) {
        let filename = response?.suggestedFilename ?? "download.bin"
        let sourceURL = response?.url
        let item = DownloadItem(filename: filename, sourceURL: sourceURL)
        downloads.insert(item, at: 0)
        downloadIDByObjectID[ObjectIdentifier(download)] = item.id
        download.delegate = self
    }

    private func updateDownload(_ id: UUID, update: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        update(&downloads[index])
    }
}

extension BrowserStore: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let webViewID = ObjectIdentifier(webView)
        guard let tabID = tabIDByWebView[webViewID] else { return }

        terminationCountByTabID[tabID] = 0
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

        if selectedTabID == tabID {
            updateNavigationState(for: webView)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        let webViewID = ObjectIdentifier(webView)
        if let tabID = tabIDByWebView[webViewID] {
            let count = (terminationCountByTabID[tabID] ?? 0) + 1
            terminationCountByTabID[tabID] = count
            if count >= 3 {
                lastNavigationWarning = "Tab process crashed repeatedly. Resetting tab to base URL."
                terminationCountByTabID[tabID] = 0
                resetTab(tabID)
                return
            }
        }
        lastNavigationWarning = "Tab process terminated unexpectedly. Reloading."
        webView.reload()
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        startTracking(
            download: download,
            response: navigationAction.request.url.flatMap {
                URLResponse(url: $0, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
            }
        )
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        startTracking(download: download, response: navigationResponse.response)
    }
}

extension BrowserStore: WKUIDelegate {}

extension BrowserStore: WKDownloadDelegate {
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let destinationURL = Self.safeDownloadURL(for: suggestedFilename)
        let downloadID = downloadIDByObjectID[ObjectIdentifier(download)]
        if let downloadID {
            updateDownload(downloadID) {
                $0.filename = suggestedFilename
                $0.sourceURL = response.url
                $0.destinationURL = destinationURL
            }
        }
        completionHandler(destinationURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let objectID = ObjectIdentifier(download)
        guard let downloadID = downloadIDByObjectID[objectID] else { return }
        updateDownload(downloadID) {
            $0.state = .finished
            $0.errorDescription = nil
        }
        downloadIDByObjectID.removeValue(forKey: objectID)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let objectID = ObjectIdentifier(download)
        guard let downloadID = downloadIDByObjectID[objectID] else { return }
        updateDownload(downloadID) {
            $0.state = .failed
            $0.errorDescription = error.localizedDescription
        }
        downloadIDByObjectID.removeValue(forKey: objectID)
    }
}

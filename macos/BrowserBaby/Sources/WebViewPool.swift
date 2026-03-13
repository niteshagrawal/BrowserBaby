import Foundation
import WebKit

@MainActor
final class WebViewPool {
    private let regularProcessPool = WKProcessPool()
    private let maxLiveViews: Int

    private var webViewsByTabID: [UUID: WKWebView] = [:]
    private var lastUseDateByTabID: [UUID: Date] = [:]

    init(maxLiveViews: Int = 6) {
        self.maxLiveViews = maxLiveViews
    }

    func webView(
        for tabID: UUID,
        initialURL: URL,
        isPrivate: Bool,
        navigationDelegate: WKNavigationDelegate,
        uiDelegate: WKUIDelegate?
    ) -> WKWebView {
        if let existing = webViewsByTabID[tabID] {
            lastUseDateByTabID[tabID] = .now
            existing.navigationDelegate = navigationDelegate
            existing.uiDelegate = uiDelegate
            return existing
        }

        let configuration = WKWebViewConfiguration()
        configuration.processPool = regularProcessPool
        configuration.websiteDataStore = isPrivate ? .nonPersistent() : .default()
        configuration.suppressesIncrementalRendering = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = false
        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = uiDelegate
        webView.load(URLRequest(url: initialURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30))

        webViewsByTabID[tabID] = webView
        lastUseDateByTabID[tabID] = .now
        trimIfNeeded(protectedTabIDs: [tabID])
        return webView
    }

    func existingWebView(for tabID: UUID) -> WKWebView? {
        webViewsByTabID[tabID]
    }

    func release(tabID: UUID) {
        guard let webView = webViewsByTabID.removeValue(forKey: tabID) else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        lastUseDateByTabID.removeValue(forKey: tabID)
    }

    func trimIfNeeded(protectedTabIDs: Set<UUID>) {
        guard webViewsByTabID.count > maxLiveViews else { return }

        let candidates = lastUseDateByTabID
            .filter { !protectedTabIDs.contains($0.key) }
            .sorted { $0.value < $1.value }

        var removeCount = webViewsByTabID.count - maxLiveViews
        for candidate in candidates where removeCount > 0 {
            release(tabID: candidate.key)
            removeCount -= 1
        }
    }
}

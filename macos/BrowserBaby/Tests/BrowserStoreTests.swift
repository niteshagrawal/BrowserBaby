import XCTest
@testable import BrowserBaby

@MainActor
final class BrowserStoreTests: XCTestCase {
    func testClosingPinnedTabResetsInsteadOfRemoving() {
        let store = BrowserStore(seedData: false)
        let id = UUID()
        let tab = BrowserTab(
            id: id,
            title: "Pinned",
            baseURL: URL(string: "https://example.com")!,
            currentURL: URL(string: "https://example.com/path")!,
            isPinned: true
        )
        store.tabs = [tab]
        store.selectedTabID = id

        let outcome = store.closeTab(id)

        XCTAssertEqual(outcome, .resetPinned)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs[0].currentURL.absoluteString, "https://example.com")
    }

    func testClosingRegularTabRemovesTab() {
        let store = BrowserStore(seedData: false)
        let id = UUID()
        store.tabs = [BrowserTab(id: id, title: "Regular", baseURL: URL(string: "https://example.com")!)]

        let outcome = store.closeTab(id)

        XCTAssertEqual(outcome, .closed)
        XCTAssertTrue(store.tabs.isEmpty)
    }

    func testReopenLastClosedTab() {
        let store = BrowserStore(seedData: false)
        let id = UUID()
        let tab = BrowserTab(id: id, title: "Close Me", baseURL: URL(string: "https://example.com")!)
        store.tabs = [tab]

        _ = store.closeTab(id)
        store.reopenLastClosedTab()

        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs[0].id, id)
    }

    func testResolveNavigationURLForDomain() {
        let url = BrowserStore.resolveNavigationURL(from: "openai.com")
        XCTAssertEqual(url?.absoluteString, "https://openai.com")
    }

    func testResolveNavigationURLForSearchQuery() {
        let url = BrowserStore.resolveNavigationURL(from: "best mac browser")
        XCTAssertEqual(url?.host(), "duckduckgo.com")
        XCTAssertTrue(url?.absoluteString.contains("q=best%20mac%20browser") == true)
    }

    func testResolveNavigationURLBlocksUnsafeScheme() {
        XCTAssertNil(BrowserStore.resolveNavigationURL(from: "javascript:alert(1)"))
        XCTAssertNil(BrowserStore.resolveNavigationURL(from: "file:///etc/passwd"))
    }

    func testSafeDownloadURLUsesBrowserBabyDownloadsFolder() {
        let url = BrowserStore.safeDownloadURL(for: "report.pdf")
        XCTAssertEqual(url.lastPathComponent, "report.pdf")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "BrowserBaby")
    }

    func testSafeDownloadURLSanitizesSlashes() {
        let url = BrowserStore.safeDownloadURL(for: "foo/bar.txt")
        XCTAssertEqual(url.lastPathComponent, "foo-bar.txt")
    }
}

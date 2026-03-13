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
}

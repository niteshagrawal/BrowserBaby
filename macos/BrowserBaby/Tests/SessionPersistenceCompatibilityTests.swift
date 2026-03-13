import XCTest
@testable import BrowserBaby

final class SessionPersistenceCompatibilityTests: XCTestCase {
    func testBrowserTabDecodeDefaultsPrivateFlagToFalse() throws {
        let json = #"{"id":"00000000-0000-0000-0000-000000000001","title":"T","baseURL":"https:\/\/example.com","currentURL":"https:\/\/example.com","isPinned":false,"isFavorite":false,"engine":"webkit","lastAccessedAt":0}"#
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let tab = try decoder.decode(BrowserTab.self, from: data)

        XCTAssertFalse(tab.isPrivate)
    }

    func testSessionSnapshotDecodeDefaultsPrivateModeAndPermissions() throws {
        let json = #"{"tabs":[],"folders":[],"selectedTabID":null,"defaultEngine":"webkit"}"#
        let data = Data(json.utf8)

        let snapshot = try JSONDecoder().decode(BrowserSessionSnapshot.self, from: data)

        XCTAssertFalse(snapshot.defaultPrivateModeEnabled)
        XCTAssertEqual(snapshot.permissionStates.count, PermissionKind.allCases.count)
        XCTAssertTrue(snapshot.recentlyClosedTabs.isEmpty)
    }
}

import Foundation

struct BrowserSessionSnapshot: Codable {
    var tabs: [BrowserTab]
    var folders: [TabFolder]
    var selectedTabID: UUID?
    var defaultEngine: BrowserEngine
    var defaultPrivateModeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case tabs
        case folders
        case selectedTabID
        case defaultEngine
        case defaultPrivateModeEnabled
    }

    init(
        tabs: [BrowserTab],
        folders: [TabFolder],
        selectedTabID: UUID?,
        defaultEngine: BrowserEngine,
        defaultPrivateModeEnabled: Bool
    ) {
        self.tabs = tabs
        self.folders = folders
        self.selectedTabID = selectedTabID
        self.defaultEngine = defaultEngine
        self.defaultPrivateModeEnabled = defaultPrivateModeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tabs = try container.decode([BrowserTab].self, forKey: .tabs)
        folders = try container.decode([TabFolder].self, forKey: .folders)
        selectedTabID = try container.decodeIfPresent(UUID.self, forKey: .selectedTabID)
        defaultEngine = try container.decode(BrowserEngine.self, forKey: .defaultEngine)
        defaultPrivateModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .defaultPrivateModeEnabled) ?? false
    }
}

@MainActor
final class SessionPersistence {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appFolder = appSupport.appendingPathComponent("BrowserBaby", isDirectory: true)
        try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
        self.fileURL = appFolder.appendingPathComponent("session.json")
    }

    func load() -> BrowserSessionSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(BrowserSessionSnapshot.self, from: data)
    }

    func save(snapshot: BrowserSessionSnapshot) {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

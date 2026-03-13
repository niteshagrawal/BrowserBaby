import Foundation

struct BrowserSessionSnapshot: Codable {
    var tabs: [BrowserTab]
    var folders: [TabFolder]
    var selectedTabID: UUID?
    var defaultEngine: BrowserEngine
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

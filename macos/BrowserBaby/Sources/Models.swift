import Foundation

enum BrowserEngine: String, CaseIterable, Codable, Identifiable {
    case webkit
    case chromium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webkit: return "WebKit"
        case .chromium: return "Chromium (Preview)"
        }
    }
}

struct BrowserTab: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var baseURL: URL
    var currentURL: URL
    var isPinned: Bool
    var isFavorite: Bool
    var engine: BrowserEngine
    var folderID: UUID?
    var lastAccessedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        baseURL: URL,
        currentURL: URL? = nil,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        engine: BrowserEngine = .webkit,
        folderID: UUID? = nil,
        lastAccessedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.baseURL = baseURL
        self.currentURL = currentURL ?? baseURL
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.engine = engine
        self.folderID = folderID
        self.lastAccessedAt = lastAccessedAt
    }
}

struct TabFolder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var pinnedTabIDs: Set<UUID>

    init(id: UUID = UUID(), name: String, pinnedTabIDs: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.pinnedTabIDs = pinnedTabIDs
    }
}

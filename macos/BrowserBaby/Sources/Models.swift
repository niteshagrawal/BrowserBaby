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
    var isPrivate: Bool
    var engine: BrowserEngine
    var folderID: UUID?
    var lastAccessedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case baseURL
        case currentURL
        case isPinned
        case isFavorite
        case isPrivate
        case engine
        case folderID
        case lastAccessedAt
    }

    init(
        id: UUID = UUID(),
        title: String,
        baseURL: URL,
        currentURL: URL? = nil,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        isPrivate: Bool = false,
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
        self.isPrivate = isPrivate
        self.engine = engine
        self.folderID = folderID
        self.lastAccessedAt = lastAccessedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        baseURL = try container.decode(URL.self, forKey: .baseURL)
        currentURL = try container.decode(URL.self, forKey: .currentURL)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        engine = try container.decode(BrowserEngine.self, forKey: .engine)
        folderID = try container.decodeIfPresent(UUID.self, forKey: .folderID)
        lastAccessedAt = try container.decode(Date.self, forKey: .lastAccessedAt)
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


enum DownloadState: String, Codable {
    case inProgress
    case finished
    case failed
}

struct DownloadItem: Identifiable, Hashable {
    let id: UUID
    var filename: String
    var sourceURL: URL?
    var destinationURL: URL?
    var state: DownloadState
    var createdAt: Date
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        filename: String,
        sourceURL: URL? = nil,
        destinationURL: URL? = nil,
        state: DownloadState = .inProgress,
        createdAt: Date = .now,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.state = state
        self.createdAt = createdAt
        self.errorDescription = errorDescription
    }
}

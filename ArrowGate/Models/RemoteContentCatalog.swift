import Foundation

/// The small, remotely published index that describes downloadable gameplay
/// content. Player data never belongs in this catalog.
struct RemoteContentCatalog: Codable, Equatable {
    let schemaVersion: Int
    let contentVersion: Int
    let minimumAppVersion: String
    let configuration: CatalogConfiguration
    let chapters: [RemoteChapterPackage]
    let events: [RemoteEventPackage]

    func validate() throws {
        guard schemaVersion == 1 else { throw RemoteContentError.unsupportedSchema(schemaVersion) }
        guard contentVersion > 0, !minimumAppVersion.isEmpty,
              configuration.levelsPerChapter > 0 else { throw RemoteContentError.invalidCatalog }
        guard Set(chapters.map(\.chapterID)).count == chapters.count,
              Set(events.map(\.eventID)).count == events.count else {
            throw RemoteContentError.duplicateIdentifier
        }
        try chapters.forEach { try $0.validate() }
        try events.forEach { try $0.validate() }
    }
}

enum RemoteContentRetention: String, Codable, CaseIterable, Hashable {
    /// Chapter/event JSON. Kept so completed content remains visible in Collection.
    case metadata
    /// Level JSON and reveal pieces. Removed after a chapter is complete.
    case gameplay
    /// Final artwork and its thumbnail. Kept for Collection.
    case reward
}

struct RemoteContentFile: Codable, Equatable, Identifiable {
    let remotePath: String
    let localPath: String
    let sha256: String
    let byteCount: Int64
    let retention: RemoteContentRetention
    /// Optional logical name used by UI code to find downloaded artwork.
    let assetName: String?

    var id: String { localPath }

    func validate() throws {
        guard Self.isSafeRelativePath(remotePath), Self.isSafeRelativePath(localPath),
              byteCount > 0,
              sha256.range(of: #"^[0-9a-fA-F]{64}$"#, options: .regularExpression) != nil else {
            throw RemoteContentError.invalidFile(localPath)
        }
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.hasPrefix("~"), !path.contains("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return !components.contains("") && !components.contains(".") && !components.contains("..")
    }
}

struct RemoteChapterPackage: Codable, Equatable, Identifiable {
    let chapterID: Int
    let version: Int
    let firstLevel: Int
    let levelCount: Int
    let files: [RemoteContentFile]

    var id: String { "chapter-\(chapterID)" }
    var lastLevel: Int { firstLevel + levelCount - 1 }

    func validate() throws {
        guard chapterID > 0, version > 0, firstLevel > 0, levelCount > 0,
              !files.isEmpty,
              Set(files.map(\.localPath)).count == files.count,
              Set(files.compactMap(\.assetName)).count == files.compactMap(\.assetName).count,
              files.contains(where: { $0.retention == .metadata && $0.localPath.hasSuffix(".json") }),
              files.contains(where: { $0.retention == .reward }) else {
            throw RemoteContentError.invalidChapter(chapterID)
        }
        try files.forEach { try $0.validate() }
    }
}

struct RemoteEventPackage: Codable, Equatable, Identifiable {
    let eventID: String
    let version: Int
    let previewStartsAt: String
    let startsAt: String
    let endsAt: String?
    let retainRewardAfterEnd: Bool
    let files: [RemoteContentFile]

    var id: String { eventID }

    var startDate: Date? { Self.formatter.date(from: startsAt) }
    var previewDate: Date? { Self.formatter.date(from: previewStartsAt) }
    var endDate: Date? { endsAt.flatMap(Self.formatter.date(from:)) }

    func validate() throws {
        guard eventID.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              version > 0,
              let previewDate, let startDate, previewDate <= startDate,
              (endDate == nil || endDate! > startDate),
              !files.isEmpty,
              Set(files.map(\.localPath)).count == files.count,
              files.contains(where: { $0.retention == .metadata && $0.localPath.hasSuffix(".json") }) else {
            throw RemoteContentError.invalidEvent(eventID)
        }
        try files.forEach { try $0.validate() }
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

enum RemoteContentError: LocalizedError, Equatable {
    case unavailable
    case unsupportedSchema(Int)
    case invalidCatalog
    case duplicateIdentifier
    case invalidChapter(Int)
    case invalidEvent(String)
    case invalidFile(String)
    case fileTooLarge(String)
    case sizeMismatch(String)
    case checksumMismatch(String)
    case minimumAppVersion(String)

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Remote content is not configured."
        case .unsupportedSchema(let version): return "Unsupported remote catalog schema \(version)."
        case .invalidCatalog: return "The remote content catalog is invalid."
        case .duplicateIdentifier: return "The remote content catalog contains duplicate identifiers."
        case .invalidChapter(let id): return "Remote chapter \(id) is invalid."
        case .invalidEvent(let id): return "Remote event \(id) is invalid."
        case .invalidFile(let path): return "Remote file \(path) is invalid."
        case .fileTooLarge(let path): return "Remote file \(path) exceeds its declared size."
        case .sizeMismatch(let path): return "Remote file \(path) has an unexpected size."
        case .checksumMismatch(let path): return "Remote file \(path) failed its integrity check."
        case .minimumAppVersion(let version): return "This content requires Pictarrow \(version) or newer."
        }
    }
}

import CryptoKit
import Foundation

struct ContentLifecycleSnapshot: Codable, Equatable {
    struct InstalledPack: Codable, Equatable {
        let version: Int
        var retainedKinds: Set<RemoteContentRetention>
        let installedAt: Date
    }

    var catalogVersion: Int?
    var installedChapters: [Int: InstalledPack]
    var installedEvents: [String: InstalledPack]

    static let empty = ContentLifecycleSnapshot(
        catalogVersion: nil,
        installedChapters: [:],
        installedEvents: [:]
    )
}

struct InstalledGameContent {
    let catalog: GameCatalog
    let assetURLs: [String: URL]
}

/// Owns downloaded content only. It never stores player progress and never
/// deletes final artwork before the replacement has passed validation.
actor ContentLifecycleManager {
    static let defaultCatalogPath = "catalog/catalog.json"

    private let transport: ContentTransport
    private let rootURL: URL
    private let catalogPath: String
    private let currentAppVersion: String
    private let bundledChapterIDs: Set<Int>
    private let fileManager: FileManager
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var catalog: RemoteContentCatalog?
    private var snapshot: ContentLifecycleSnapshot

    init(
        transport: ContentTransport,
        rootURL: URL,
        catalogPath: String = ContentLifecycleManager.defaultCatalogPath,
        currentAppVersion: String,
        bundledChapterIDs: Set<Int> = [],
        fileManager: FileManager = .default
    ) throws {
        self.transport = transport
        self.rootURL = rootURL
        self.catalogPath = catalogPath
        self.currentAppVersion = currentAppVersion
        self.bundledChapterIDs = bundledChapterIDs
        self.fileManager = fileManager
        encoder.outputFormatting = [.sortedKeys]
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        snapshot = Self.loadSnapshot(from: rootURL.appendingPathComponent("content-state.json"), decoder: decoder) ?? .empty
        catalog = Self.loadCatalog(from: rootURL.appendingPathComponent("catalog.json"), decoder: decoder)
    }

    static func defaultRootURL(
        fileManager: FileManager = .default,
        directoryName: String = "PictarrowContent"
    ) throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support.appendingPathComponent(directoryName, isDirectory: true)
    }

    @discardableResult
    func refreshCatalog() async throws -> RemoteContentCatalog {
        let data = try await transport.fetchData(at: catalogPath, maximumSize: 5 * 1_024 * 1_024)
        let downloaded = try decoder.decode(RemoteContentCatalog.self, from: data)
        try downloaded.validate()
        guard Self.compareVersions(currentAppVersion, downloaded.minimumAppVersion) != .orderedAscending else {
            throw RemoteContentError.minimumAppVersion(downloaded.minimumAppVersion)
        }
        let catalogURL = rootURL.appendingPathComponent("catalog.json")
        try data.write(to: catalogURL, options: .atomic)
        try excludeFromBackup(catalogURL)
        catalog = downloaded
        snapshot.catalogVersion = downloaded.contentVersion
        try persistSnapshot()
        return downloaded
    }

    /// Keeps the current chapter and the following two chapters ready. Earlier
    /// chapters keep their lightweight JSON, plus final artwork when completed,
    /// so an existing player's catalog remains contiguous after a clean refresh.
    @discardableResult
    func reconcile(
        unlockedLevel: Int,
        completedChapterIDs: Set<Int>,
        completedEventIDs: Set<String> = [],
        now: Date = Date()
    ) async throws -> ContentLifecycleSnapshot {
        guard let catalog else { throw RemoteContentError.unavailable }

        let orderedChapters = catalog.chapters.sorted { $0.firstLevel < $1.firstLevel }
        let currentIndex = orderedChapters.firstIndex {
            $0.firstLevel <= unlockedLevel && unlockedLevel <= $0.lastLevel
        } ?? orderedChapters.firstIndex { $0.firstLevel > unlockedLevel } ?? max(0, orderedChapters.count - 1)
        let desiredRange = currentIndex..<min(orderedChapters.count, currentIndex + 3)
        let desiredIDs = Set(desiredRange.map { orderedChapters[$0].chapterID })
        let priorIDs = Set(orderedChapters[..<currentIndex].map(\.chapterID))

        for index in orderedChapters.indices where index < currentIndex {
            let chapter = orderedChapters[index]
            guard !bundledChapterIDs.contains(chapter.chapterID) else { continue }
            let retainedKinds: Set<RemoteContentRetention> = completedChapterIDs.contains(chapter.chapterID)
                ? [.metadata, .reward]
                : [.metadata]
            try await install(chapter, retaining: retainedKinds)
        }

        for index in desiredRange {
            let chapter = orderedChapters[index]
            guard !bundledChapterIDs.contains(chapter.chapterID) else { continue }
            try await install(chapter, retaining: Set(RemoteContentRetention.allCases))
        }

        for chapter in orderedChapters where completedChapterIDs.contains(chapter.chapterID) {
            guard !bundledChapterIDs.contains(chapter.chapterID),
                  snapshot.installedChapters[chapter.chapterID] != nil else { continue }
            try await install(chapter, retaining: [.metadata, .reward])
        }

        for chapterID in Array(snapshot.installedChapters.keys)
        where !desiredIDs.contains(chapterID) && !priorIDs.contains(chapterID) {
            try removeChapter(chapterID)
        }

        for event in catalog.events {
            guard let previewDate = event.previewDate, event.startDate != nil else { continue }
            let hasEnded = event.endDate.map { now >= $0 } ?? false
            if now >= previewDate && !hasEnded {
                try await install(event, retaining: Set(RemoteContentRetention.allCases))
            } else if hasEnded {
                if event.retainRewardAfterEnd && completedEventIDs.contains(event.eventID) {
                    try await install(event, retaining: [.metadata, .reward])
                } else {
                    try removeEvent(event.eventID)
                }
            }
        }

        try persistSnapshot()
        return snapshot
    }

    func currentSnapshot() -> ContentLifecycleSnapshot { snapshot }

    func installedGameContent() throws -> InstalledGameContent {
        guard let remote = catalog else { throw RemoteContentError.unavailable }
        let chapterCatalogs: [ChapterCatalog] = try remote.chapters
            .sorted { $0.chapterID < $1.chapterID }
            .compactMap { package in
                guard snapshot.installedChapters[package.chapterID] != nil,
                      let file = package.files.first(where: { $0.retention == .metadata && $0.localPath.hasSuffix(".json") }) else {
                    return nil
                }
                let url = packageRoot(kind: "chapters", id: package.id, version: package.version)
                    .appendingPathComponent(file.localPath)
                guard fileManager.fileExists(atPath: url.path) else { return nil }
                return try decoder.decode(ChapterCatalog.self, from: Data(contentsOf: url))
            }
        guard !chapterCatalogs.isEmpty else { throw RemoteContentError.unavailable }

        let eventCatalogs: [GameEventCatalog] = try remote.events
            .compactMap { package in
                guard snapshot.installedEvents[package.eventID] != nil,
                      let file = package.files.first(where: { $0.retention == .metadata && $0.localPath.hasSuffix(".json") }) else {
                    return nil
                }
                let url = packageRoot(kind: "events", id: package.id, version: package.version)
                    .appendingPathComponent(file.localPath)
                guard fileManager.fileExists(atPath: url.path) else { return nil }
                return try decoder.decode(GameEventCatalog.self, from: Data(contentsOf: url))
            }
        let gameCatalog = try LevelRepository.assemble(
            version: remote.contentVersion,
            configuration: remote.configuration,
            chapters: chapterCatalogs,
            events: eventCatalogs
        )
        var assets: [String: URL] = [:]
        for package in remote.chapters where snapshot.installedChapters[package.chapterID] != nil {
            let root = packageRoot(kind: "chapters", id: package.id, version: package.version)
            for file in package.files where file.assetName != nil {
                let url = root.appendingPathComponent(file.localPath)
                if fileManager.fileExists(atPath: url.path), let name = file.assetName { assets[name] = url }
            }
        }
        for package in remote.events where snapshot.installedEvents[package.eventID] != nil {
            let root = packageRoot(kind: "events", id: package.id, version: package.version)
            for file in package.files where file.assetName != nil {
                let url = root.appendingPathComponent(file.localPath)
                if fileManager.fileExists(atPath: url.path), let name = file.assetName { assets[name] = url }
            }
        }
        return InstalledGameContent(catalog: gameCatalog, assetURLs: assets)
    }

    func localURL(forAssetNamed assetName: String) -> URL? {
        guard let catalog else { return nil }
        for chapter in catalog.chapters {
            guard let file = chapter.files.first(where: { $0.assetName == assetName }) else { continue }
            let url = packageRoot(kind: "chapters", id: chapter.id, version: chapter.version)
                .appendingPathComponent(file.localPath)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        for event in catalog.events {
            guard let file = event.files.first(where: { $0.assetName == assetName }) else { continue }
            let url = packageRoot(kind: "events", id: event.id, version: event.version)
                .appendingPathComponent(file.localPath)
            if fileManager.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    func localCatalogURL(forChapterID chapterID: Int) -> URL? {
        guard let package = catalog?.chapters.first(where: { $0.chapterID == chapterID }),
              let file = package.files.first(where: { $0.localPath.hasSuffix(".json") && $0.retention == .metadata }) else {
            return nil
        }
        let url = packageRoot(kind: "chapters", id: package.id, version: package.version)
            .appendingPathComponent(file.localPath)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func install(_ package: RemoteChapterPackage, retaining kinds: Set<RemoteContentRetention>) async throws {
        let previousInstallation = snapshot.installedChapters[package.chapterID]
        let root = packageRoot(kind: "chapters", id: package.id, version: package.version)
        try await install(files: package.files.filter { kinds.contains($0.retention) }, under: root)
        try remove(files: package.files.filter { !kinds.contains($0.retention) }, under: root)
        try removeOtherVersions(kind: "chapters", id: package.id, keeping: package.version)
        snapshot.installedChapters[package.chapterID] = .init(
            version: package.version,
            retainedKinds: kinds,
            installedAt: previousInstallation?.version == package.version
                ? previousInstallation?.installedAt ?? Date()
                : Date()
        )
    }

    private func install(_ package: RemoteEventPackage, retaining kinds: Set<RemoteContentRetention>) async throws {
        let previousInstallation = snapshot.installedEvents[package.eventID]
        let root = packageRoot(kind: "events", id: package.id, version: package.version)
        try await install(files: package.files.filter { kinds.contains($0.retention) }, under: root)
        try remove(files: package.files.filter { !kinds.contains($0.retention) }, under: root)
        try removeOtherVersions(kind: "events", id: package.id, keeping: package.version)
        snapshot.installedEvents[package.eventID] = .init(
            version: package.version,
            retainedKinds: kinds,
            installedAt: previousInstallation?.version == package.version
                ? previousInstallation?.installedAt ?? Date()
                : Date()
        )
    }

    private func install(files: [RemoteContentFile], under root: URL) async throws {
        for file in files {
            let destination = root.appendingPathComponent(file.localPath)
            if try isValid(file, at: destination) { continue }
            let staging = rootURL.appendingPathComponent("Staging", isDirectory: true)
                .appendingPathComponent(UUID().uuidString)
            try fileManager.createDirectory(at: staging.deletingLastPathComponent(), withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: staging) }
            try await transport.downloadFile(at: file.remotePath, to: staging)
            try validate(file, at: staging)
            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fileManager.removeItem(at: destination)
            try fileManager.moveItem(at: staging, to: destination)
            try excludeFromBackup(destination)
        }
    }

    private func validate(_ file: RemoteContentFile, at url: URL) throws {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              Int64(values.fileSize ?? -1) == file.byteCount else {
            throw RemoteContentError.sizeMismatch(file.localPath)
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard digest.caseInsensitiveCompare(file.sha256) == .orderedSame else {
            throw RemoteContentError.checksumMismatch(file.localPath)
        }
    }

    private func isValid(_ file: RemoteContentFile, at url: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        do { try validate(file, at: url); return true }
        catch { try? fileManager.removeItem(at: url); return false }
    }

    private func remove(files: [RemoteContentFile], under root: URL) throws {
        for file in files {
            let url = root.appendingPathComponent(file.localPath)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    private func removeEvent(_ id: String) throws {
        let directory = rootURL.appendingPathComponent("events", isDirectory: true).appendingPathComponent(id, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
        snapshot.installedEvents[id] = nil
    }

    private func removeChapter(_ chapterID: Int) throws {
        guard let package = catalog?.chapters.first(where: { $0.chapterID == chapterID }) else { return }
        let directory = rootURL.appendingPathComponent("chapters", isDirectory: true)
            .appendingPathComponent(package.id, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) { try fileManager.removeItem(at: directory) }
        snapshot.installedChapters[chapterID] = nil
    }

    private func removeOtherVersions(kind: String, id: String, keeping version: Int) throws {
        let base = rootURL.appendingPathComponent(kind, isDirectory: true).appendingPathComponent(id, isDirectory: true)
        guard fileManager.fileExists(atPath: base.path) else { return }
        for url in try fileManager.contentsOfDirectory(at: base, includingPropertiesForKeys: nil)
        where url.lastPathComponent != "v\(version)" {
            try fileManager.removeItem(at: url)
        }
    }

    private func packageRoot(kind: String, id: String, version: Int) -> URL {
        rootURL.appendingPathComponent(kind, isDirectory: true)
            .appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent("v\(version)", isDirectory: true)
    }

    private func persistSnapshot() throws {
        let stateURL = rootURL.appendingPathComponent("content-state.json")
        try encoder.encode(snapshot).write(to: stateURL, options: .atomic)
        try excludeFromBackup(stateURL)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    private static func loadSnapshot(from url: URL, decoder: JSONDecoder) -> ContentLifecycleSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ContentLifecycleSnapshot.self, from: data)
    }

    private static func loadCatalog(from url: URL, decoder: JSONDecoder) -> RemoteContentCatalog? {
        guard let data = try? Data(contentsOf: url),
              let catalog = try? decoder.decode(RemoteContentCatalog.self, from: data),
              (try? catalog.validate()) != nil else { return nil }
        return catalog
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }
}

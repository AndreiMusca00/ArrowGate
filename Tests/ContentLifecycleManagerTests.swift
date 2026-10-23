import CryptoKit
import Foundation
import XCTest
@testable import ArrowGateRules

final class ContentLifecycleManagerTests: XCTestCase {
    func testDownloadsCurrentAndNextTwoWithoutProgressThreshold() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let metadata = Data("chapter metadata".utf8)
        let reward = Data("final artwork".utf8)
        let chapters = (1...4).map {
            package(id: $0, firstLevel: (($0 - 1) * 25) + 1, gameplay: metadata, reward: reward)
        }
        let catalog = RemoteContentCatalog(
            schemaVersion: 1,
            contentVersion: 1,
            minimumAppVersion: "1.0",
            configuration: CatalogConfiguration(levelsPerChapter: 25),
            chapters: chapters,
            events: []
        )
        let transport = MemoryContentTransport(files: try files(for: catalog, game: metadata, reward: reward))
        let manager = try ContentLifecycleManager(
            transport: transport,
            rootURL: root,
            currentAppVersion: "1.0"
        )

        try await manager.refreshCatalog()
        var snapshot = try await manager.reconcile(unlockedLevel: 1, completedChapterIDs: [])
        XCTAssertEqual(Set(snapshot.installedChapters.keys), [1, 2, 3])
        XCTAssertNil(snapshot.installedChapters[4])

        snapshot = try await manager.reconcile(unlockedLevel: 26, completedChapterIDs: [1])
        XCTAssertEqual(Set(snapshot.installedChapters.keys), [1, 2, 3, 4])
        XCTAssertEqual(snapshot.installedChapters[1]?.retainedKinds, [.metadata, .reward])
        XCTAssertEqual(snapshot.installedChapters[2]?.retainedKinds, Set(RemoteContentRetention.allCases))
    }

    func testPrefetchesNextChapterAndRetainsOnlyRewardAfterCompletion() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let game = Data("chapter gameplay".utf8)
        let reward = Data("final artwork".utf8)
        let chapter2 = package(id: 2, firstLevel: 26, gameplay: game, reward: reward)
        let chapter3 = package(id: 3, firstLevel: 51, gameplay: game, reward: reward)
        let catalog = RemoteContentCatalog(
            schemaVersion: 1,
            contentVersion: 1,
            minimumAppVersion: "1.0",
            configuration: CatalogConfiguration(levelsPerChapter: 25),
            chapters: [chapter2, chapter3],
            events: []
        )
        let transport = MemoryContentTransport(files: try files(for: catalog, game: game, reward: reward))
        let manager = try ContentLifecycleManager(
            transport: transport,
            rootURL: root,
            currentAppVersion: "1.0",
            bundledChapterIDs: [1]
        )

        try await manager.refreshCatalog()
        var snapshot = try await manager.reconcile(unlockedLevel: 45, completedChapterIDs: [])
        XCTAssertEqual(snapshot.installedChapters[2]?.retainedKinds, Set(RemoteContentRetention.allCases))
        XCTAssertEqual(snapshot.installedChapters[3]?.retainedKinds, Set(RemoteContentRetention.allCases))

        snapshot = try await manager.reconcile(unlockedLevel: 51, completedChapterIDs: [2])
        XCTAssertEqual(snapshot.installedChapters[2]?.retainedKinds, [.metadata, .reward])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("chapters/chapter-2/v1/chapter.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("chapters/chapter-2/v1/final.webp").path))
    }

    func testBrokenReplacementDoesNotDeleteValidatedPreviousVersion() async throws {
        let root = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let game = Data("chapter gameplay".utf8)
        let reward = Data("final artwork".utf8)
        let version1 = package(id: 2, version: 1, firstLevel: 26, gameplay: game, reward: reward)
        let firstCatalog = RemoteContentCatalog(
            schemaVersion: 1, contentVersion: 1, minimumAppVersion: "1.0",
            configuration: CatalogConfiguration(levelsPerChapter: 25),
            chapters: [version1], events: []
        )
        let transport = MemoryContentTransport(files: try files(for: firstCatalog, game: game, reward: reward))
        let manager = try ContentLifecycleManager(
            transport: transport, rootURL: root, currentAppVersion: "1.0", bundledChapterIDs: [1]
        )

        try await manager.refreshCatalog()
        try await manager.reconcile(unlockedLevel: 26, completedChapterIDs: [])

        let broken = Data("corrupt replacement".utf8)
        let version2 = package(id: 2, version: 2, firstLevel: 26, gameplay: game, reward: reward)
        let secondCatalog = RemoteContentCatalog(
            schemaVersion: 1, contentVersion: 2, minimumAppVersion: "1.0",
            configuration: CatalogConfiguration(levelsPerChapter: 25),
            chapters: [version2], events: []
        )
        await transport.replaceFiles(try files(for: secondCatalog, game: broken, reward: reward))
        try await manager.refreshCatalog()

        do {
            _ = try await manager.reconcile(unlockedLevel: 26, completedChapterIDs: [])
            XCTFail("Expected checksum validation to fail")
        } catch RemoteContentError.sizeMismatch {
            // Expected: the declared v2 gameplay size belongs to the valid data.
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("chapters/chapter-2/v1/final.webp").path))
    }

    private func package(
        id: Int,
        version: Int = 1,
        firstLevel: Int,
        gameplay: Data,
        reward: Data
    ) -> RemoteChapterPackage {
        let base = "chapters/chapter-\(id)/v\(version)"
        return RemoteChapterPackage(
            chapterID: id,
            version: version,
            firstLevel: firstLevel,
            levelCount: 25,
            files: [
                file(remote: "\(base)/chapter.json", local: "chapter.json", data: gameplay, retention: .metadata),
                file(remote: "\(base)/final.webp", local: "final.webp", data: reward, retention: .reward, assetName: "Chapter\(id)Complete")
            ]
        )
    }

    private func file(
        remote: String,
        local: String,
        data: Data,
        retention: RemoteContentRetention,
        assetName: String? = nil
    ) -> RemoteContentFile {
        RemoteContentFile(
            remotePath: remote,
            localPath: local,
            sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            byteCount: Int64(data.count),
            retention: retention,
            assetName: assetName
        )
    }

    private func files(for catalog: RemoteContentCatalog, game: Data, reward: Data) throws -> [String: Data] {
        var result = [ContentLifecycleManager.defaultCatalogPath: try JSONEncoder().encode(catalog)]
        for package in catalog.chapters {
            for file in package.files {
                result[file.remotePath] = file.retention == .metadata ? game : reward
            }
        }
        return result
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}

private actor MemoryContentTransport: ContentTransport {
    private var files: [String: Data]

    init(files: [String: Data]) { self.files = files }

    func replaceFiles(_ files: [String: Data]) { self.files = files }

    func fetchData(at path: String, maximumSize: Int64) async throws -> Data {
        guard let data = files[path] else { throw URLError(.fileDoesNotExist) }
        guard data.count <= maximumSize else { throw RemoteContentError.fileTooLarge(path) }
        return data
    }

    func downloadFile(at path: String, to destination: URL) async throws {
        guard let data = files[path] else { throw URLError(.fileDoesNotExist) }
        try data.write(to: destination, options: .atomic)
    }
}

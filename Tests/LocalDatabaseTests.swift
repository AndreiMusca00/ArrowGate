import XCTest
import SQLite3
import CoreData
@testable import ArrowGateRules

final class LocalDatabaseTests: XCTestCase {
    func testExistingStoreMigratesWhenChapterEntityIsAdded() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy-current.sqlite")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let model = NSManagedObjectModel()
        func entity(_ name: String, _ fields: [(String, NSAttributeType)]) -> NSEntityDescription {
            let result = NSEntityDescription(); result.name = name; result.managedObjectClassName = "NSManagedObject"
            result.properties = fields.map { name, type in
                let attribute = NSAttributeDescription(); attribute.name = name
                attribute.attributeType = type; attribute.isOptional = false
                return attribute
            }
            return result
        }
        let level = entity("StoredLevel", [("id", .integer64AttributeType), ("payload", .binaryDataAttributeType)])
        level.uniquenessConstraints = [["id"]]
        let metadata = entity("Metadata", [("key", .stringAttributeType), ("value", .stringAttributeType)])
        metadata.uniquenessConstraints = [["key"]]
        model.entities = [level, metadata]
        var oldContainer: NSPersistentContainer? = NSPersistentContainer(name: "ArrowGateLocal", managedObjectModel: model)
        oldContainer!.persistentStoreDescriptions = [NSPersistentStoreDescription(url: url)]
        var loadError: Error?
        oldContainer!.loadPersistentStores { _, error in loadError = error }
        XCTAssertNil(loadError)
        let row = NSEntityDescription.insertNewObject(forEntityName: "Metadata", into: oldContainer!.viewContext)
        row.setValue("unlocked", forKey: "key"); row.setValue("3", forKey: "value")
        try oldContainer!.viewContext.save()
        if let store = oldContainer!.persistentStoreCoordinator.persistentStores.first {
            try oldContainer!.persistentStoreCoordinator.remove(store)
        }
        oldContainer = nil

        let suite = "ChapterMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let migrated = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(migrated.unlocked, 3)
        XCTAssertEqual(migrated.savedChapters.map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(migrated.savedLevels.count, LevelRepository.count)
    }
    func testLevelsProgressAndPreferencesSurviveReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game.sqlite")
        let suite = "LocalDB.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = try LocalDatabase(url: url)
        let store = ProgressStore(defaults: defaults, database: database)
        XCTAssertEqual(store.savedLevels.count, LevelRepository.count)
        XCTAssertEqual(store.savedChapters.count, 4)
        XCTAssertEqual(store.hints, 3)
        XCTAssertTrue(store.consumeHint())
        store.sound = false; store.haptics = false
        store.complete(6, time: 12); store.complete(6, time: 20)
        XCTAssertEqual(store.completedLevels, Set(1...6))
        let reopened = try LocalDatabase(url: url)
        let restored = ProgressStore(defaults: defaults, database: reopened)
        XCTAssertEqual(restored.unlocked, 7)
        XCTAssertEqual(restored.hints, 2)
        restored.grantHint(2)
        XCTAssertEqual(try reopened.metadata("hints"), "4")
        XCTAssertEqual(restored.completedLevels, Set(1...6))
        XCTAssertFalse(restored.sound); XCTAssertFalse(restored.haptics)
        XCTAssertEqual(try reopened.metadata("bestTime.6"), "12.0")
        XCTAssertEqual(try reopened.metadata("firstCompletionTime.6"), "12.0")
        XCTAssertEqual(try reopened.metadata("lastCompletionTime.6"), "20.0")
        XCTAssertEqual(try reopened.metadata("totalCompletionTime.6"), "32.0")
        XCTAssertEqual(try reopened.metadata("completionCount.6"), "2")
        XCTAssertEqual(restored.savedLevels.map(\.id), Array(1...LevelRepository.count))
        XCTAssertEqual(restored.savedLevels[16].definition.arrows.map(\.cells), LevelRepository.level(17).arrows.map(\.cells))
        restored.complete(LevelRepository.count, time: 40)
        XCTAssertEqual(try reopened.metadata("campaignCompleted"), "1")
        restored.reset()
        XCTAssertEqual(restored.unlocked, 1)
        XCTAssertEqual(restored.hints, 3)
        XCTAssertTrue(restored.completedLevels.isEmpty)
        XCTAssertNil(try reopened.metadata("bestTime.6"))
        XCTAssertNil(try reopened.metadata("firstCompletionTime.6"))
        XCTAssertNil(try reopened.metadata("lastCompletionTime.6"))
        XCTAssertNil(try reopened.metadata("totalCompletionTime.6"))
        XCTAssertNil(try reopened.metadata("completionCount.6"))
        XCTAssertNil(try reopened.metadata("campaignCompleted"))
        XCTAssertEqual(try reopened.levels().count, LevelRepository.count)
        XCTAssertEqual(try reopened.chapters().count, 4)
        XCTAssertFalse(restored.sound)
        let resetStore = ProgressStore(defaults: defaults, database: reopened)
        XCTAssertEqual(resetStore.unlocked, 1)
        XCTAssertEqual(resetStore.hints, 3)
    }
    func testUnfinishedLevelSessionSurvivesReloadAndClearsOnCompletion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalDBSession.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("game.sqlite")
        let level = LevelRepository.level(1)
        let removed = try XCTUnwrap(level.arrows.first?.id)
        let snapshot = LevelSessionSnapshot(
            levelID: level.id,
            removedArrowIDs: [removed],
            penalizedArrowIDs: Set(level.arrows.dropFirst().prefix(1).map(\.id)),
            hearts: 2,
            mistakes: 1,
            elapsed: 18.4,
            hintsUsed: 1
        )

        let store = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        store.saveSession(snapshot)
        XCTAssertEqual(store.activeSession, snapshot)

        let reopened = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(reopened.session(for: level), snapshot)
        reopened.complete(level.id, time: 21)
        XCTAssertNil(reopened.activeSession)
        XCTAssertNil(try LocalDatabase(url: url).activeSession())
    }
    func testMilestoneRewardsArePersistedAndGrantedOnce() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalDBRewards.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("game.sqlite")
        let store = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))

        XCTAssertEqual(store.complete(5, time: 20), LevelCompletionReward(kind: .hint))
        XCTAssertEqual(store.hints, 4)
        XCTAssertNil(store.complete(5, time: 18))
        XCTAssertEqual(store.hints, 4)

        XCTAssertEqual(store.complete(10, time: 30), LevelCompletionReward(kind: .hint))
        XCTAssertEqual(store.hints, 5)
        XCTAssertNil(store.complete(10, time: 25))
        XCTAssertEqual(store.hints, 5)

        let restored = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(restored.hints, 5)
        XCTAssertNil(restored.complete(10, time: 20))
    }
    func testHalloweenCompletionIsUniquePersistentAndSeparateFromCampaign() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "HalloweenProgress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("game.sqlite")
        let event = try XCTUnwrap(LevelRepository.event("eventHalloween"))
        let puzzles = LevelRepository.eventPuzzles(for: event.id)
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-14T12:00:00Z"))
        let store = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertTrue(store.isEventLevelUnlocked(event.id, levelID: puzzles[0].id))
        XCTAssertFalse(store.isEventLevelUnlocked(event.id, levelID: puzzles[1].id))
        XCTAssertFalse(store.completeEventLevel(event.id, levelID: puzzles[29].id, on: date))
        XCTAssertTrue(store.completeEventLevel(event.id, levelID: puzzles[0].id, on: date))
        XCTAssertFalse(store.completeEventLevel(event.id, levelID: puzzles[0].id, on: date))
        XCTAssertTrue(store.isEventLevelUnlocked(event.id, levelID: puzzles[1].id))
        XCTAssertFalse(store.isEventLevelUnlocked(event.id, levelID: puzzles[2].id))
        XCTAssertFalse(store.completeEventLevel(event.id, levelID: 1, on: date))
        XCTAssertEqual(store.progress(for: event, at: date), 1)
        XCTAssertEqual(store.unlocked, 1)
        XCTAssertTrue(store.completedLevels.isEmpty)
        let restored = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(restored.completedEventLevels[event.id], Set([puzzles[0].id]))
        XCTAssertEqual(restored.progress(for: event, at: date), 1)
        for puzzle in puzzles.dropFirst() {
            XCTAssertTrue(restored.isEventLevelUnlocked(event.id, levelID: puzzle.id))
            XCTAssertTrue(restored.completeEventLevel(event.id, levelID: puzzle.id, on: date))
        }
        XCTAssertEqual(restored.progress(for: event, at: date), 30)
        XCTAssertEqual(restored.unlocked, 1)
        restored.reset()
        XCTAssertEqual(restored.progress(for: event, at: date), 0)
        let reset = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertTrue(reset.completedEventLevels[event.id, default: []].isEmpty)
    }

    func testHalloweenFallbackStorageSurvivesReload() throws {
        let suite = "HalloweenFallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let event = try XCTUnwrap(LevelRepository.event("eventHalloween"))
        let puzzle = try XCTUnwrap(LevelRepository.eventPuzzles(for: event.id).first)
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-05T12:00:00Z"))
        let store = ProgressStore(defaults: defaults)
        XCTAssertTrue(store.completeEventLevel(event.id, levelID: puzzle.id, on: date))
        let restored = ProgressStore(defaults: defaults)
        XCTAssertEqual(restored.completedEventLevels[event.id], Set([puzzle.id]))
        XCTAssertEqual(restored.progress(for: event, at: date), 1)
    }

    func testDailyEventProgressAndMonthlyTrophyPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "LocalDBEvents.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = directory.appendingPathComponent("game.sqlite")
        let event = try XCTUnwrap(LevelRepository.events.first { $0.kind == .dailyChallenge })
        let today = Date()
        let month = ProgressStore.monthKey(for: today)
        let store = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))

        for _ in 0..<event.progress.goal { store.recordEventCompletion(event, on: today) }
        XCTAssertEqual(store.progress(for: event, at: today), event.progress.goal)
        XCTAssertTrue(store.hasTrophy(for: event, monthKey: month))

        let restored = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(restored.progress(for: event, at: today), event.progress.goal)
        XCTAssertTrue(restored.hasTrophy(for: event, monthKey: month))
    }
    func testReadOnlyProgressImportIsOneTimeAndResetStaysReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let previous = directory.appendingPathComponent("previous.sqlite")
        var connection: OpaquePointer?
        XCTAssertEqual(sqlite3_open(previous.path, &connection), SQLITE_OK)
        defer { sqlite3_close(connection) }
        XCTAssertEqual(sqlite3_exec(connection, """
            CREATE TABLE ZMETADATA (ZKEY TEXT, ZVALUE TEXT);
            INSERT INTO ZMETADATA VALUES ('unlocked','8'),('bestTime.7','18.5'),('campaignCompleted','1'),
            ('bestTime.1000','1.0'),('other','ignored');
            """, nil, nil, nil), SQLITE_OK)
        let database = try LocalDatabase(url: directory.appendingPathComponent("new.sqlite"))
        try database.importProgress(from: previous)
        XCTAssertEqual(try database.metadata("unlocked"), "8")
        XCTAssertEqual(try database.metadata("bestTime.7"), "18.5")
        XCTAssertNil(try database.metadata("bestTime.1000"))
        XCTAssertNil(try database.metadata("other"))
        let suite = "LocalDBMigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let migrated = ProgressStore(defaults: defaults, database: database)
        XCTAssertEqual(migrated.unlocked, 9)
        XCTAssertTrue(migrated.completedLevels.contains(8))
        XCTAssertFalse(migrated.completedLevels.contains(LevelRepository.count))
        XCTAssertEqual(try database.metadata("campaignCompleted"), "0")
        try database.resetProgress()
        try database.importProgress(from: previous)
        XCTAssertEqual(try database.metadata("unlocked"), "1")
        XCTAssertNil(try database.metadata("bestTime.7"))
    }
}

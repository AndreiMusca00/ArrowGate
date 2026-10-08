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
        XCTAssertEqual(migrated.savedChapters.map(\.id), [1, 2])
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
        XCTAssertEqual(store.savedChapters.count, 2)
        XCTAssertEqual(store.hints, 3)
        XCTAssertEqual(store.reserveLives, 1)
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
        XCTAssertEqual(restored.savedLevels.map(\.id), Array(1...LevelRepository.count))
        XCTAssertEqual(restored.savedLevels[16].definition.arrows.map(\.cells), LevelRepository.level(17).arrows.map(\.cells))
        restored.complete(LevelRepository.count, time: 40)
        XCTAssertEqual(try reopened.metadata("campaignCompleted"), "1")
        restored.reset()
        XCTAssertEqual(restored.unlocked, 1)
        XCTAssertEqual(restored.hints, 3)
        XCTAssertEqual(restored.reserveLives, 1)
        XCTAssertTrue(restored.completedLevels.isEmpty)
        XCTAssertNil(try reopened.metadata("bestTime.6"))
        XCTAssertNil(try reopened.metadata("campaignCompleted"))
        XCTAssertEqual(try reopened.levels().count, LevelRepository.count)
        XCTAssertEqual(try reopened.chapters().count, 2)
        XCTAssertFalse(restored.sound)
        let resetStore = ProgressStore(defaults: defaults, database: reopened)
        XCTAssertEqual(resetStore.unlocked, 1)
        XCTAssertEqual(resetStore.hints, 3)
        XCTAssertEqual(resetStore.reserveLives, 1)
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

        XCTAssertEqual(store.complete(10, time: 30), LevelCompletionReward(kind: .life))
        XCTAssertEqual(store.reserveLives, 2)
        XCTAssertNil(store.complete(10, time: 25))
        XCTAssertEqual(store.reserveLives, 2)

        let restored = ProgressStore(defaults: defaults, database: try LocalDatabase(url: url))
        XCTAssertEqual(restored.hints, 4)
        XCTAssertEqual(restored.reserveLives, 2)
        XCTAssertNil(restored.complete(10, time: 20))
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

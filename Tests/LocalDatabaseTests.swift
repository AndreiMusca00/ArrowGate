import XCTest
import SQLite3
@testable import ArrowGateRules

final class LocalDatabaseTests: XCTestCase {
    func testLevelsProgressAndPreferencesSurviveReload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("game.sqlite")
        let suite = "LocalDB.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = try LocalDatabase(url: url)
        let store = ProgressStore(defaults: defaults, database: database)
        XCTAssertEqual(store.savedLevels.count, 20)
        store.sound = false; store.haptics = false
        store.complete(6, time: 12); store.complete(6, time: 20)
        XCTAssertEqual(store.completedLevels, Set(1...6))
        let reopened = try LocalDatabase(url: url)
        let restored = ProgressStore(defaults: defaults, database: reopened)
        XCTAssertEqual(restored.unlocked, 7)
        XCTAssertEqual(restored.completedLevels, Set(1...6))
        XCTAssertFalse(restored.sound); XCTAssertFalse(restored.haptics)
        XCTAssertEqual(try reopened.metadata("bestTime.6"), "12.0")
        XCTAssertEqual(restored.savedLevels.map(\.id), Array(1...20))
        XCTAssertEqual(restored.savedLevels[16].definition.arrows.map(\.cells), LevelRepository.level(17).arrows.map(\.cells))
        restored.complete(20, time: 40)
        XCTAssertEqual(try reopened.metadata("campaignCompleted"), "1")
        restored.reset()
        XCTAssertEqual(restored.unlocked, 1)
        XCTAssertTrue(restored.completedLevels.isEmpty)
        XCTAssertNil(try reopened.metadata("bestTime.6"))
        XCTAssertNil(try reopened.metadata("campaignCompleted"))
        XCTAssertEqual(try reopened.levels().count, 20)
        XCTAssertFalse(restored.sound)
        XCTAssertEqual(ProgressStore(defaults: defaults, database: reopened).unlocked, 1)
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
        try database.resetProgress()
        try database.importProgress(from: previous)
        XCTAssertEqual(try database.metadata("unlocked"), "1")
        XCTAssertNil(try database.metadata("bestTime.7"))
    }
}

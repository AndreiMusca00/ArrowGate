import Foundation
import CoreData
import SQLite3

struct SavedLevel: Identifiable {
    let id: Int
    let definition: LevelDefinition
}

struct SavedChapter: Identifiable {
    let id: Int
    let definition: ChapterDefinition
}

/// Persists only published levels and campaign progress.
final class LocalDatabase {
    private let container: NSPersistentContainer
    private var context: NSManagedObjectContext { container.viewContext }

    static func defaultURL(testing: Bool = false) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(testing ? "ArrowGateLocalTests.sqlite" : "ArrowGateLocal.sqlite")
    }
    static var previousURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ArrowGate.sqlite")
    }
    init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let model = NSManagedObjectModel()
        func entity(_ name: String, _ fields: [(String, NSAttributeType)]) -> NSEntityDescription {
            let entity = NSEntityDescription()
            entity.name = name; entity.managedObjectClassName = "NSManagedObject"
            entity.properties = fields.map { name, type in
                let attribute = NSAttributeDescription()
                attribute.name = name; attribute.attributeType = type; attribute.isOptional = false
                return attribute
            }
            return entity
        }
        let level = entity("StoredLevel", [("id", .integer64AttributeType), ("payload", .binaryDataAttributeType)])
        level.uniquenessConstraints = [["id"]]
        let chapter = entity("StoredChapter", [("id", .integer64AttributeType), ("payload", .binaryDataAttributeType)])
        chapter.uniquenessConstraints = [["id"]]
        let metadata = entity("Metadata", [("key", .stringAttributeType), ("value", .stringAttributeType)])
        metadata.uniquenessConstraints = [["key"]]
        model.entities = [level, chapter, metadata]
        container = NSPersistentContainer(name: "ArrowGateLocal", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    private func transaction<T>(_ work: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        context.performAndWait {
            do {
                let value = try work()
                if context.hasChanges { try context.save() }
                result = .success(value)
            } catch { context.rollback(); result = .failure(error) }
        }
        return try result.get()
    }
    private func rows(_ entity: String, predicate: NSPredicate? = nil) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity); request.predicate = predicate
        return try context.fetch(request)
    }
    private func setMetadata(_ key: String, _ value: String) throws {
        let row = try rows("Metadata", predicate: NSPredicate(format: "key == %@", key)).first
            ?? NSEntityDescription.insertNewObject(forEntityName: "Metadata", into: context)
        row.setValue(key, forKey: "key"); row.setValue(value, forKey: "value")
    }
    func metadata(_ key: String) throws -> String? {
        try transaction { try rows("Metadata", predicate: NSPredicate(format: "key == %@", key)).first?.value(forKey: "value") as? String }
    }
    /// Imports only campaign progress from the previous prototype's store.
    /// Opening it read-only avoids keeping the previous data model in this project.
    func importProgress(from url: URL) throws {
        guard try metadata("previousProgressImported") == nil else { return }
        var values: [String: String] = [:]
        if FileManager.default.fileExists(atPath: url.path) {
            var connection: OpaquePointer?
            guard sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                if let connection { sqlite3_close(connection) }
                throw CocoaError(.fileReadUnknown)
            }
            defer { sqlite3_close(connection) }
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(connection, "SELECT ZKEY, ZVALUE FROM ZMETADATA", -1, &statement, nil) == SQLITE_OK else {
                throw CocoaError(.fileReadCorruptFile)
            }
            defer { sqlite3_finalize(statement) }
            var status = sqlite3_step(statement)
            while status == SQLITE_ROW {
                if let keyBytes = sqlite3_column_text(statement, 0), let valueBytes = sqlite3_column_text(statement, 1) {
                    let key = String(cString: keyBytes), value = String(cString: valueBytes)
                    let isBestTime = key.hasPrefix("bestTime.") && (1...LevelRepository.count).contains(Int(key.dropFirst(9)) ?? 0)
                    if key == "unlocked" || key == "campaignCompleted" || isBestTime { values[key] = value }
                }
                status = sqlite3_step(statement)
            }
            guard status == SQLITE_DONE else { throw CocoaError(.fileReadUnknown) }
        }
        try transaction {
            for (key, value) in values where try metadata(key) == nil { try setMetadata(key, value) }
            try setMetadata("previousProgressImported", "1")
        }
    }
    func initializeProgress(defaults: UserDefaults) throws {
        try transaction {
            if try metadata("unlocked") == nil {
                try setMetadata("unlocked", String(min(LevelRepository.count, max(1, defaults.integer(forKey: "unlockedLevel")))))
                for id in 1...LevelRepository.count where defaults.double(forKey: "bestTime.\(id)") > 0 {
                    try setMetadata("bestTime.\(id)", String(defaults.double(forKey: "bestTime.\(id)")))
                }
                if defaults.bool(forKey: "campaignCompleted") { try setMetadata("campaignCompleted", "1") }
            }
            if try metadata("hints") == nil {
                let stored = defaults.object(forKey: "hintCount") == nil ? 3 : defaults.integer(forKey: "hintCount")
                try setMetadata("hints", String(max(0, stored)))
            }
            if try metadata("reserveLives") == nil {
                let stored = defaults.object(forKey: "reserveLifeCount") == nil ? 1 : defaults.integer(forKey: "reserveLifeCount")
                try setMetadata("reserveLives", String(max(0, stored)))
            }
            var unlocked = Int(try metadata("unlocked") ?? "1") ?? 1
            // A completed older campaign stored its final level as `unlocked` because
            // there was no following level. When a chapter is appended, advance it once.
            if try metadata("campaignCompleted") == "1", unlocked < LevelRepository.count {
                try setMetadata("completed.\(unlocked)", "1")
                unlocked += 1
                try setMetadata("unlocked", String(unlocked))
                try setMetadata("campaignCompleted", "0")
            }
            for id in 1..<min(max(unlocked, 1), LevelRepository.count + 1) where try metadata("completed.\(id)") == nil {
                try setMetadata("completed.\(id)", "1")
            }
            if try metadata("campaignCompleted") == "1" {
                try setMetadata("completed.\(LevelRepository.count)", "1")
            }
        }
    }
    func saveChapters(_ chapters: [ChapterDefinition]) throws {
        try transaction {
            let identifiers = Set(chapters.map(\.id))
            for row in try rows("StoredChapter") {
                if !identifiers.contains(Int(row.value(forKey: "id") as! Int64)) { context.delete(row) }
            }
            for chapter in chapters {
                let row = try rows("StoredChapter", predicate: NSPredicate(format: "id == %lld", Int64(chapter.id))).first
                    ?? NSEntityDescription.insertNewObject(forEntityName: "StoredChapter", into: context)
                row.setValue(Int64(chapter.id), forKey: "id")
                row.setValue(try JSONEncoder().encode(chapter), forKey: "payload")
            }
        }
    }
    func chapters() throws -> [SavedChapter] {
        try transaction {
            try rows("StoredChapter").map { row in
                SavedChapter(id: Int(row.value(forKey: "id") as! Int64),
                             definition: try JSONDecoder().decode(ChapterDefinition.self, from: row.value(forKey: "payload") as! Data))
            }.sorted { $0.id < $1.id }
        }
    }
    func saveLevels(_ levels: [LevelDefinition]) throws {
        try transaction {
            let identifiers = Set(levels.map(\.id))
            for row in try rows("StoredLevel") {
                if !identifiers.contains(Int(row.value(forKey: "id") as! Int64)) { context.delete(row) }
            }
            for level in levels {
                let row = try rows("StoredLevel", predicate: NSPredicate(format: "id == %lld", Int64(level.id))).first
                    ?? NSEntityDescription.insertNewObject(forEntityName: "StoredLevel", into: context)
                row.setValue(Int64(level.id), forKey: "id")
                row.setValue(try JSONEncoder().encode(level), forKey: "payload")
            }
        }
    }
    func levels() throws -> [SavedLevel] {
        try transaction {
            try rows("StoredLevel").map { row in
                SavedLevel(id: Int(row.value(forKey: "id") as! Int64),
                           definition: try JSONDecoder().decode(LevelDefinition.self, from: row.value(forKey: "payload") as! Data))
            }.sorted { $0.id < $1.id }
        }
    }
    @discardableResult
    func complete(_ level: Int, time: Double, reward: LevelCompletionReward? = nil) throws -> Bool {
        guard (1...LevelRepository.count).contains(level), time.isFinite, time >= 0 else { return false }
        return try transaction {
            let firstCompletion = try metadata("completed.\(level)") != "1"
            let unlocked = Int(try metadata("unlocked") ?? "1") ?? 1
            try setMetadata("unlocked", String(max(unlocked, min(LevelRepository.count, level + 1))))
            let key = "bestTime.\(level)"
            let best = Double(try metadata(key) ?? "") ?? .infinity
            if time < best { try setMetadata(key, String(time)) }
            if level == LevelRepository.count { try setMetadata("campaignCompleted", "1") }
            try setMetadata("completed.\(level)", "1")
            if firstCompletion, let reward {
                let inventoryKey = reward.kind == .hint ? "hints" : "reserveLives"
                let current = Int(try metadata(inventoryKey) ?? "0") ?? 0
                try setMetadata(inventoryKey, String(max(0, current) + reward.amount))
            }
            return firstCompletion
        }
    }
    func setHintCount(_ count: Int) throws {
        try transaction { try setMetadata("hints", String(max(0, count))) }
    }
    func setReserveLifeCount(_ count: Int) throws {
        try transaction { try setMetadata("reserveLives", String(max(0, count))) }
    }
    func resetProgress() throws {
        try transaction {
            for row in try rows("Metadata") {
                let key = row.value(forKey: "key") as! String
                if key == "campaignCompleted" || key.hasPrefix("bestTime.") || key.hasPrefix("completed.") { context.delete(row) }
            }
            try setMetadata("unlocked", "1")
            try setMetadata("hints", "3")
            try setMetadata("reserveLives", "1")
        }
    }
}

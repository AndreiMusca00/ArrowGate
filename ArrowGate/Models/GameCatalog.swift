import Foundation

struct CatalogConfiguration: Codable, Equatable {
    let levelsPerChapter: Int
}

/// Small manifest that tells the app which independently published chapter
/// files belong to the current campaign.
struct CatalogIndex: Codable {
    let version: Int
    let configuration: CatalogConfiguration
    let chapterFiles: [String]
    let eventFiles: [String]?
}

/// One self-contained chapter payload. Future online updates can replace or
/// add this file without rewriting previously published chapters.
struct ChapterCatalog: Codable {
    let chapter: ChapterDefinition
    let levels: [LevelDefinition]
}

enum GameEventKind: String, Codable {
    case dailyChallenge
    case limitedCollection
}

enum GameEventDecoration: String, Codable {
    case orbitDots
    case spiderWeb
    case fallingLeaves
    case none
}

enum GameEventRewardKind: String, Codable {
    case monthlyTrophy
    case assembledArtwork
}

struct GameEventSchedule: Codable, Equatable {
    let previewStartsAt: String
    let startsAt: String
    let endsAt: String?
    /// Temporary access for reviewing an event before its normal start date.
    let testingStartsAt: String?
}

struct GameEventProgressDefinition: Codable, Equatable {
    let goal: Int
    let unitName: String
}

struct GameEventRewardDefinition: Codable, Equatable {
    let kind: GameEventRewardKind
    let title: String
    let subtitle: String
    let pieceCount: Int
    let systemSymbol: String
    let assetName: String?
}

struct GameEventStyleDefinition: Codable, Equatable {
    let primaryColor: String
    let secondaryColor: String
    let backgroundColor: String
    let decoration: GameEventDecoration
    let symbol: String
}

struct GameEventDefinition: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let kind: GameEventKind
    let priority: Int
    let schedule: GameEventSchedule
    let progress: GameEventProgressDefinition
    let reward: GameEventRewardDefinition
    let style: GameEventStyleDefinition
}

struct EventPuzzleDefinition: Identifiable, Codable {
    let day: Int
    let date: String
    let level: LevelDefinition
    var id: Int { level.id }
}

struct GameEventCatalog: Codable {
    let event: GameEventDefinition
    let levels: [EventPuzzleDefinition]?
}

enum GameEventLifecycleState: Equatable {
    case hidden
    case comingSoon
    case active
    case ended
}

extension GameEventDefinition {
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    var previewDate: Date? { Self.dateFormatter.date(from: schedule.previewStartsAt) }
    var startDate: Date? { Self.dateFormatter.date(from: schedule.startsAt) }
    var endDate: Date? { schedule.endsAt.flatMap(Self.dateFormatter.date(from:)) }
    var testingStartDate: Date? { schedule.testingStartsAt.flatMap(Self.dateFormatter.date(from:)) }

    func lifecycle(at date: Date = Date()) -> GameEventLifecycleState {
        guard let previewDate, let startDate else { return .hidden }
        if date < previewDate { return .hidden }
        let availableFrom = testingStartDate ?? startDate
        if date < availableFrom { return .comingSoon }
        if let endDate, date >= endDate { return .ended }
        return .active
    }

    func appearsOnHome(at date: Date = Date()) -> Bool {
        switch lifecycle(at: date) {
        case .hidden: return false
        case .comingSoon, .active: return true
        case .ended: return false
        }
    }
}

/// Fully assembled in-memory catalog used by the rest of the app.
struct GameCatalog {
    let version: Int
    let configuration: CatalogConfiguration
    let chapters: [ChapterDefinition]
    let levels: [LevelDefinition]
    let events: [GameEventDefinition]
    let eventPuzzles: [String: [EventPuzzleDefinition]]
}

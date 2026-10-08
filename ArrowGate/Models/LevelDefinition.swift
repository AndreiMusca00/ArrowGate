import Foundation

enum LevelDifficulty: String, Codable {
    case tutorial, easy, normal, hard, veryHard, nightmare
    var title: String {
        switch self {
        case .veryHard: return "Very Hard"
        default: return rawValue.capitalized
        }
    }
}

enum LevelRewardKind: String, Codable {
    case hint, life
}

struct LevelCompletionReward: Codable, Equatable {
    let kind: LevelRewardKind
    let amount: Int

    init(kind: LevelRewardKind, amount: Int = 1) {
        self.kind = kind
        self.amount = max(1, amount)
    }
}

struct ChapterStyleDefinition: Codable, Equatable {
    let primaryColor: String
    let secondaryColor: String
    let backgroundColor: String
    let decorations: [String]
    let galleryCardHeight: Double
    let galleryCornerRadius: Double
    let detailBackgroundOpacity: Double
    let mapCornerRadius: Double
    let mapBackgroundOpacity: Double
    let mapBorderOpacity: Double
}

struct ChapterDefinition: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let subtitle: String
    let levelCount: Int
    let symbol: String
    let style: ChapterStyleDefinition
}

enum ArrowColor: String, CaseIterable, Codable { case yellow, blue, green, red, brown, cyan }
enum Direction: Int, CaseIterable, Codable {
    case right, up, left, down
    var dx: Int { self == .right ? 1 : self == .left ? -1 : 0 }
    var dy: Int { self == .up ? 1 : self == .down ? -1 : 0 }
}
struct Cell: Hashable, Codable {
    let x: Int
    let y: Int
    func moved(_ direction: Direction, by distance: Int = 1) -> Cell {
        Cell(x: x + direction.dx * distance, y: y + direction.dy * distance)
    }
}
struct ArrowDefinition: Identifiable, Codable {
    let id: Int
    let head: Cell
    let direction: Direction
    let color: ArrowColor
    let length: Int
    let body: [Cell]?
    init(id: Int, head: Cell, direction: Direction, color: ArrowColor, length: Int, body: [Cell]? = nil) {
        self.id = id; self.head = head; self.direction = direction; self.color = color
        self.length = body?.count ?? length; self.body = body
    }
    var cells: [Cell] { body ?? (0..<length).map { head.moved(direction, by: -$0) } }
    var gateKey: GateKey { GateKey(side: direction, lane: direction.dx == 0 ? head.x : head.y) }
}
struct GateKey: Hashable, Codable { let side: Direction; let lane: Int }
struct GateDefinition: Codable {
    let key: GateKey
    let color: ArrowColor
    let thawAfterMoves: Int
    init(key: GateKey, color: ArrowColor, thawAfterMoves: Int = 0) {
        self.key = key; self.color = color; self.thawAfterMoves = thawAfterMoves
    }
}
struct TargetCell: Hashable, Codable {
    let cell: Cell
    let color: ArrowColor
}
struct LevelDefinition: Identifiable, Codable {
    let id: Int
    let chapterID: Int
    let size: Int
    let height: Int
    let timeLimit: TimeInterval
    let arrows: [ArrowDefinition]
    let gates: [GateDefinition]
    let difficulty: LevelDifficulty?
    /// Cells that belong to an irregular board. `nil` keeps the legacy rectangle.
    let activeCells: [Cell]?
    /// Required final colour for authored image cells. Only a matching arrow may reveal it.
    let targetCells: [TargetCell]?
    /// Optional polished reward image revealed after the pixel painting is complete.
    let completionArtwork: String?
    /// Native emoji used as the polished collectible when no custom artwork is supplied.
    let rewardEmoji: String?
    let rewardName: String?
    let completionReward: LevelCompletionReward?
    init(id: Int, chapterID: Int = 1, size: Int, height: Int? = nil, timeLimit: TimeInterval = 180,
         arrows: [ArrowDefinition], gates: [GateDefinition], difficulty: LevelDifficulty? = nil,
         activeCells: [Cell]? = nil, targetCells: [TargetCell]? = nil,
         completionArtwork: String? = nil, rewardEmoji: String? = nil,
         rewardName: String? = nil, completionReward: LevelCompletionReward? = nil) {
        self.id = id; self.chapterID = chapterID; self.size = size; self.height = height ?? size
        self.timeLimit = timeLimit; self.arrows = arrows; self.gates = gates
        self.difficulty = difficulty; self.activeCells = activeCells; self.targetCells = targetCells
        self.completionArtwork = completionArtwork
        self.rewardEmoji = rewardEmoji; self.rewardName = rewardName
        self.completionReward = completionReward
    }
    func contains(_ cell: Cell) -> Bool {
        guard (0..<size).contains(cell.x), (0..<height).contains(cell.y) else { return false }
        return activeCells?.contains(cell) ?? true
    }
}

import Foundation

enum LevelDifficulty: String, Codable {
    case tutorial, easy, normal, hard, superHard
    var title: String { self == .superHard ? "Super Hard" : rawValue.capitalized }
}
enum ArrowColor: String, CaseIterable, Codable { case yellow, blue, green, red, brown }
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
    init(id: Int, size: Int, height: Int? = nil, timeLimit: TimeInterval = 180,
         arrows: [ArrowDefinition], gates: [GateDefinition], difficulty: LevelDifficulty? = nil,
         activeCells: [Cell]? = nil, targetCells: [TargetCell]? = nil,
         completionArtwork: String? = nil) {
        self.id = id; self.size = size; self.height = height ?? size
        self.timeLimit = timeLimit; self.arrows = arrows; self.gates = gates
        self.difficulty = difficulty; self.activeCells = activeCells; self.targetCells = targetCells
        self.completionArtwork = completionArtwork
    }
    func contains(_ cell: Cell) -> Bool {
        guard (0..<size).contains(cell.x), (0..<height).contains(cell.y) else { return false }
        return activeCells?.contains(cell) ?? true
    }
}

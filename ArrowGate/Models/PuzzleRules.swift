import Foundation

enum MoveResult: Equatable { case allowed, blocked }
enum PuzzleRules {
    static func evaluate(_ arrow: ArrowDefinition, remaining: [ArrowDefinition], level: LevelDefinition) -> MoveResult {
        let occupied = Set(remaining.filter { $0.id != arrow.id }.flatMap(\.cells) + Array(arrow.cells.dropFirst()))
        var cell = arrow.head.moved(arrow.direction)
        while level.contains(cell) {
            if occupied.contains(cell) { return .blocked }
            cell = cell.moved(arrow.direction)
        }
        return .allowed
    }
    /// First contact along the head's lane, including an arrow's own bent body.
    static func blockingCell(_ arrow: ArrowDefinition, remaining: [ArrowDefinition], level: LevelDefinition) -> Cell? {
        let occupied = Set(remaining.filter { $0.id != arrow.id }.flatMap(\.cells) + Array(arrow.cells.dropFirst()))
        var cell = arrow.head.moved(arrow.direction)
        while level.contains(cell) {
            if occupied.contains(cell) { return cell }
            cell = cell.moved(arrow.direction)
        }
        return nil
    }
    static func hint(remaining: [ArrowDefinition], level: LevelDefinition) -> ArrowDefinition? {
        remaining.first { evaluate($0, remaining: remaining, level: level) == .allowed }
    }
}
enum LevelValidator {
    static func solution(for level: LevelDefinition) -> [Int]? {
        guard level.size > 0, level.height > 0, level.timeLimit.isFinite, (level.timeLimit > 0 || (level.id == 1 && level.difficulty == .tutorial && level.timeLimit == 0)), !level.arrows.isEmpty,
              Set(level.arrows.map(\.id)).count == level.arrows.count,
              level.arrows.allSatisfy({ arrow in
                  let cells = arrow.cells
                  return arrow.length > 0 && cells.count == arrow.length && cells.first == arrow.head &&
                      (cells.count < 2 || cells[1] == arrow.head.moved(arrow.direction, by: -1)) &&
                      zip(cells, cells.dropFirst()).allSatisfy { abs($0.x - $1.x) + abs($0.y - $1.y) == 1 }
              }) else { return nil }
        let cells = level.arrows.flatMap(\.cells)
        guard cells.allSatisfy(level.contains), Set(cells).count == cells.count else { return nil }
        var remaining = level.arrows
        var result: [Int] = []
        // Removing an arrow can only free space: every legal choice preserves solvability.
        while !remaining.isEmpty {
            guard let next = PuzzleRules.hint(remaining: remaining, level: level) else { return nil }
            result.append(next.id)
            remaining.removeAll { $0.id == next.id }
        }
        return result
    }
}

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
        let authoredCells = level.activeCells.map(Set.init)
        func containsFast(_ cell: Cell) -> Bool {
            guard (0..<level.size).contains(cell.x), (0..<level.height).contains(cell.y) else { return false }
            return authoredCells?.contains(cell) ?? true
        }
        let cells = level.arrows.flatMap(\.cells)
        guard cells.allSatisfy(containsFast), Set(cells).count == cells.count else { return nil }
        if let activeCells = level.activeCells {
            let insideBounds = activeCells.allSatisfy {
                (0..<level.size).contains($0.x) && (0..<level.height).contains($0.y)
            }
            guard !activeCells.isEmpty, insideBounds,
                  Set(activeCells).count == activeCells.count,
                  Set(cells) == Set(activeCells) else { return nil }
        }
        if let targets = level.targetCells {
            let targetCells = targets.map(\.cell)
            guard !targets.isEmpty,
                  Set(targetCells).count == targetCells.count,
                  targetCells.allSatisfy(level.contains) else { return nil }
            if let activeCells = level.activeCells {
                guard Set(targetCells) == Set(activeCells) else { return nil }
            }

            var reachableByColor: [ArrowColor: Set<Cell>] = [:]
            for arrow in level.arrows {
                var reachable = arrow.cells
                var cell = arrow.head.moved(arrow.direction)
                while containsFast(cell) {
                    reachable.append(cell)
                    cell = cell.moved(arrow.direction)
                }
                reachableByColor[arrow.color, default: []].formUnion(reachable)
            }
            guard targets.allSatisfy({ reachableByColor[$0.color]?.contains($0.cell) == true }) else {
                return nil
            }
        }
        // Build the blocker graph once. Repeatedly scanning every remaining
        // arrow made catalog validation needlessly expensive for large boards.
        // An arrow can leave exactly when every owner on the ray in front of
        // its head has already left, so a topological ordering is the solution.
        let owner = Dictionary(uniqueKeysWithValues: level.arrows.flatMap { arrow in
            arrow.cells.map { ($0, arrow.id) }
        })
        var blockers: [Int: Set<Int>] = [:]
        var dependants: [Int: Set<Int>] = [:]
        for arrow in level.arrows {
            var arrowBlockers: Set<Int> = []
            var cell = arrow.head.moved(arrow.direction)
            while containsFast(cell) {
                if let blocker = owner[cell] {
                    guard blocker != arrow.id else { return nil }
                    arrowBlockers.insert(blocker)
                }
                cell = cell.moved(arrow.direction)
            }
            blockers[arrow.id] = arrowBlockers
            for blocker in arrowBlockers {
                dependants[blocker, default: []].insert(arrow.id)
            }
        }

        var ready = level.arrows.map(\.id).filter { blockers[$0]?.isEmpty == true }
        var cursor = 0
        var result: [Int] = []
        while cursor < ready.count {
            let removed = ready[cursor]
            cursor += 1
            result.append(removed)
            for dependant in dependants[removed, default: []] {
                blockers[dependant]?.remove(removed)
                if blockers[dependant]?.isEmpty == true {
                    ready.append(dependant)
                }
            }
        }
        return result.count == level.arrows.count ? result : nil
    }

}

import XCTest
@testable import ArrowGateRules

final class CandidateCatalogTests: XCTestCase {
    func testCandidateChapterWhenRequested() throws {
        guard let path = ProcessInfo.processInfo.environment["PICTARROW_CANDIDATE_CHAPTER"] else {
            throw XCTSkip("Set PICTARROW_CANDIDATE_CHAPTER to validate an unpublished chapter.")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let candidate = try JSONDecoder().decode(ChapterCatalog.self, from: data)
        XCTAssertEqual(candidate.levels.count, candidate.chapter.levelCount)
        XCTAssertEqual(candidate.levels.map(\.id), Array(1...candidate.levels.count))

        for level in candidate.levels {
            XCTAssertEqual(level.timeLimit, 0, "Level \(level.id) unexpectedly has a timer")
            XCTAssertEqual(Set(level.arrows.map(\.id)).count, level.arrows.count)
            XCTAssertTrue(level.arrows.allSatisfy { $0.cells.count >= 3 }, "Level \(level.id) has a short arrow")
            XCTAssertTrue(level.arrows.allSatisfy { $0.cells.first == $0.head })

            let ownedCells = level.arrows.flatMap(\.cells)
            XCTAssertEqual(Set(ownedCells).count, ownedCells.count, "Level \(level.id) has overlapping arrows")
            XCTAssertEqual(Set(ownedCells), Set(try XCTUnwrap(level.activeCells)))

            let targets = try XCTUnwrap(level.targetCells)
            XCTAssertEqual(Set(targets.map(\.cell)), Set(ownedCells))
            let targetColors = Dictionary(uniqueKeysWithValues: targets.map { ($0.cell, $0.color) })
            XCTAssertTrue(level.arrows.allSatisfy { arrow in
                arrow.cells.allSatisfy { targetColors[$0] == arrow.color }
            }, "Level \(level.id) has target colours that cannot be painted")

            let solution = try XCTUnwrap(LevelValidator.solution(for: level), "Level \(level.id) is unsolvable")
            XCTAssertEqual(solution.count, level.arrows.count)
        }
    }
}

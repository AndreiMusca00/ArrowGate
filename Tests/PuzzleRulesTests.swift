import XCTest
@testable import ArrowGateRules

final class PuzzleRulesTests: XCTestCase {
    func testExportUIFixtures() throws {
        guard let path = ProcessInfo.processInfo.environment["ARROWGATE_FIXTURES"] else { return }
        struct Fixture: Codable {
            let number: Int
            let size: Int
            let height: Int
            let gates: [GateDefinition]
            let arrows: [ArrowDefinition]
            let solution: [Int]
        }
        let fixtures = try LevelRepository.levels.map { level in
            Fixture(number: level.id, size: level.size, height: level.height, gates: level.gates,
                    arrows: level.arrows, solution: try XCTUnwrap(LevelValidator.solution(for: level)))
        }
        try JSONEncoder().encode(fixtures).write(to: URL(fileURLWithPath: path))
    }
    func testAllPublishedLevelsAndEveryLegalChoice() throws {
        XCTAssertEqual(LevelRepository.version, 14)
        XCTAssertEqual(LevelRepository.levelsPerChapter, 25)
        XCTAssertEqual(LevelRepository.levels.count, 100)
        for level in LevelRepository.levels {
            let solution = try XCTUnwrap(LevelValidator.solution(for: level))
            XCTAssertEqual(solution.count, level.arrows.count)
            var remaining = level.arrows
            for id in solution {
                let arrow = try XCTUnwrap(remaining.first { $0.id == id })
                XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: remaining, level: level), .allowed)
                remaining.removeAll { $0.id == id }
            }
            XCTAssertTrue(remaining.isEmpty)
            let exhaustiveSamples: Set<Int> = [1, 5, 8, 12, 25, 26, 30, 50, 51, 55, 75, 76, 80]
            if exhaustiveSamples.contains(level.id) {
                for first in level.arrows where PuzzleRules.evaluate(first, remaining: level.arrows, level: level) == .allowed {
                    var alternate = level.arrows.filter { $0.id != first.id }
                    while let arrow = PuzzleRules.hint(remaining: alternate, level: level) {
                        alternate.removeAll { $0.id == arrow.id }
                    }
                    XCTAssertTrue(alternate.isEmpty, "Legal choice must not create a dead end")
                }
            }
        }
    }
    func testCampaignDifficultyShapesAndTimeBudgets() throws {
        for level in LevelRepository.levels {
            XCTAssertTrue(level.gates.allSatisfy { $0.thawAfterMoves == 0 })
            XCTAssertTrue(level.arrows.allSatisfy { arrow in
                guard let body = arrow.body else { return false }
                return body.count == arrow.length && !body.isEmpty
            })
            XCTAssertTrue(level.arrows.allSatisfy { $0.length >= 3 })
            XCTAssertNotNil(LevelValidator.solution(for: level))
            XCTAssertEqual(level.timeLimit, 0)
        }
        for chapter in LevelRepository.chapters {
            let levels = LevelRepository.levels(in: chapter)
            XCTAssertGreaterThanOrEqual(levels.filter { $0.difficulty == .hard }.count, 2)
            XCTAssertGreaterThanOrEqual(levels.filter { $0.difficulty == .veryHard }.count, 2)
            XCTAssertGreaterThanOrEqual(levels.filter { $0.difficulty == .nightmare }.count, 2)
            XCTAssertEqual(Set(levels.flatMap(\.arrows).map(\.direction)), Set(Direction.allCases))
            let chapterColourCount = Set(levels.flatMap(\.arrows).map(\.color)).count
            XCTAssertGreaterThan(chapterColourCount, 1)
        }
        XCTAssertEqual(LevelRepository.level(5).difficulty, .hard)
        XCTAssertEqual(LevelRepository.level(8).difficulty, .veryHard)
        XCTAssertEqual(LevelRepository.level(25).difficulty, .nightmare)
    }
    func testMappedArrowColoursHaveContrastAgainstWhite() throws {
        for level in LevelRepository.levels {
            for arrow in level.arrows {
                let rgb = try XCTUnwrap(UInt32(arrow.color.hex.dropFirst(), radix: 16))
                func linear(_ value: UInt32) -> Double {
                    let channel = Double(value) / 255
                    return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
                }
                let luminance = 0.2126 * linear((rgb >> 16) & 255)
                    + 0.7152 * linear((rgb >> 8) & 255)
                    + 0.0722 * linear(rgb & 255)
                XCTAssertGreaterThanOrEqual(1.05 / (luminance + 0.05), 4.5)
            }
        }
    }

    func testTrialArrowBudgetsAndDifficultyDistribution() {
        for chapter in LevelRepository.chapters {
            let levels = LevelRepository.levels(in: chapter)
            XCTAssertEqual(levels.filter { $0.difficulty == .hard }.count, 6)
            XCTAssertEqual(levels.filter { $0.difficulty == .veryHard }.count, 4)
            XCTAssertEqual(levels.filter { $0.difficulty == .nightmare }.count, 2)
            XCTAssertEqual(levels.filter { $0.difficulty == .easy || $0.difficulty == .tutorial }.count, 13)
            for level in levels {
                let count: Int
                switch level.difficulty {
                case .hard: count = [1: 75, 2: 45, 3: 60, 4: 75][chapter.id]!
                case .veryHard: count = [1: 100, 2: 60, 3: 80, 4: 100][chapter.id]!
                case .nightmare: count = level.id == 100 ? 250 : [1: 150, 2: 80, 3: 110, 4: 150][chapter.id]!
                default: count = [1: 50, 2: 30, 3: 40, 4: 50][chapter.id]!
                }
                XCTAssertEqual(level.arrows.count, count, "Level \(level.id)")
                XCTAssertTrue(level.arrows.allSatisfy { $0.length >= 3 })
            }
        }
    }

    func testAllPublishedBoardsAreAuthoredCollectiblePaintings() throws {
        XCTAssertEqual(Set(LevelRepository.levels.compactMap(\.rewardName)).count, 100)
        for level in LevelRepository.levels {
            let activeCells = try XCTUnwrap(level.activeCells)
            let targetCells = try XCTUnwrap(level.targetCells)
            XCTAssertEqual(Set(activeCells), Set(level.arrows.flatMap(\.cells)))
            XCTAssertEqual(Set(activeCells), Set(targetCells.map(\.cell)))
            XCTAssertEqual(targetCells.count, activeCells.count)
            XCTAssertLessThan(activeCells.count, level.size * level.height)
            XCTAssertNotNil(level.completionArtwork)
            XCTAssertNotNil(level.rewardName)
            XCTAssertNotNil(LevelValidator.solution(for: level))
        }
        XCTAssertGreaterThanOrEqual(Set(LevelRepository.levels.map { "\($0.size)x\($0.height)" }).count, 8)
        XCTAssertTrue(LevelRepository.levels.allSatisfy { level in
            level.arrows.map(\.length).reduce(into: Set<Int>()) { $0.insert($1) }.count >= 2
        })
        for chapter in LevelRepository.chapters {
            XCTAssertEqual(LevelRepository.levels(in: chapter).count, 25)
            XCTAssertEqual(chapter.levelCount, 25)
            XCTAssertEqual(chapter.assembly?.pieceCount, 24)
        }
        XCTAssertEqual(LevelRepository.chapters.map(\.levelCount), [25, 25, 25, 25])
        XCTAssertEqual(LevelRepository.levels.map(\.chapterID), Array(repeating: 1, count: 25) + Array(repeating: 2, count: 25) + Array(repeating: 3, count: 25) + Array(repeating: 4, count: 25))
        XCTAssertEqual(
            LevelRepository.levels.prefix(24).compactMap(\.completionArtwork),
            (1...24).map { String(format: "EnchantedTreePiece%02d", $0) }
        )
        XCTAssertEqual(LevelRepository.level(25).completionArtwork, "EnchantedTreeComplete")
        XCTAssertEqual(LevelRepository.level(25).difficulty, .nightmare)
        XCTAssertEqual(LevelRepository.level(5).completionReward, LevelCompletionReward(kind: .hint))
        XCTAssertEqual(LevelRepository.level(10).completionReward, LevelCompletionReward(kind: .hint))
    }
    func testWatermillChapterArtworkAndProgression() {
        let chapter = LevelRepository.chapter(2)
        XCTAssertEqual(chapter.assembly?.assetPrefix, "ForestWatermillPiece")
        XCTAssertEqual(chapter.assembly?.finalArtwork, "ForestWatermillComplete")
        XCTAssertEqual(LevelRepository.levels(in: chapter).map(\.id), Array(26...50))
        XCTAssertEqual(LevelRepository.levels(in: chapter).prefix(24).compactMap(\.completionArtwork),
                       (1...24).map { String(format: "ForestWatermillPiece%02d", $0) })
        XCTAssertEqual(LevelRepository.level(50).completionArtwork, "ForestWatermillComplete")
        XCTAssertEqual(LevelRepository.level(26).difficulty, .easy)
        XCTAssertEqual(LevelRepository.level(50).difficulty, .nightmare)
    }

    func testMushroomVillageChapterArtworkAndProgression() {
        let chapter = LevelRepository.chapter(3)
        XCTAssertEqual(chapter.assembly?.assetPrefix, "ForestMushroomPiece")
        XCTAssertEqual(chapter.assembly?.finalArtwork, "ForestMushroomComplete")
        XCTAssertEqual(LevelRepository.levels(in: chapter).map(\.id), Array(51...75))
        XCTAssertEqual(LevelRepository.levels(in: chapter).prefix(24).compactMap(\.completionArtwork),
                       (1...24).map { String(format: "ForestMushroomPiece%02d", $0) })
        XCTAssertEqual(LevelRepository.level(75).completionArtwork, "ForestMushroomComplete")
        XCTAssertEqual(LevelRepository.level(51).difficulty, .easy)
        XCTAssertEqual(LevelRepository.level(75).difficulty, .nightmare)
    }

    func testSanctuaryChapterAndFinalChallenge() throws {
        let chapter = LevelRepository.chapter(4)
        XCTAssertEqual(chapter.assembly?.assetPrefix, "ForestSanctuaryPiece")
        XCTAssertEqual(chapter.assembly?.finalArtwork, "ForestSanctuaryComplete")
        XCTAssertEqual(LevelRepository.levels(in: chapter).map(\.id), Array(76...100))
        XCTAssertEqual(LevelRepository.levels(in: chapter).prefix(24).compactMap(\.completionArtwork),
                       (1...24).map { String(format: "ForestSanctuaryPiece%02d", $0) })
        let finale = LevelRepository.level(100)
        XCTAssertEqual(finale.completionArtwork, "ForestSanctuaryComplete")
        XCTAssertEqual(finale.difficulty, .nightmare)
        XCTAssertEqual(finale.arrows.count, 250)
        XCTAssertGreaterThanOrEqual(max(finale.size, finale.height), 60)
        XCTAssertNotNil(LevelValidator.solution(for: finale))
        XCTAssertTrue(finale.arrows.allSatisfy { $0.length >= 3 })
        // Replay the published solution with the actual game rules.
        var remaining = finale.arrows
        for id in try XCTUnwrap(LevelValidator.solution(for: finale)) {
            let arrow = try XCTUnwrap(remaining.first { $0.id == id })
            XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: remaining, level: finale), .allowed)
            remaining.removeAll { $0.id == id }
        }
        XCTAssertTrue(remaining.isEmpty)
    }

    func testCollisionChecksEveryCellAndLongArrowTailInAllDirections() {
        for direction in Direction.allCases {
            let head = Cell(x: 3, y: 3)
            let arrow = ArrowDefinition(id: 0, head: head, direction: direction, color: .yellow, length: 2)
            let obstacle = ArrowDefinition(id: 1, head: head.moved(direction, by: 3), direction: direction, color: .blue, length: 2)
            let level = LevelDefinition(id: 1, size: 7, arrows: [arrow, obstacle], gates: [GateDefinition(key: arrow.gateKey, color: .yellow)])
            XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: [arrow, obstacle], level: level), .blocked)
            XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: [arrow], level: level), .allowed)
        }
    }
    func testPortalMetadataDoesNotRestrictMovementAndOverlapsRemainInvalid() {
        let arrow = ArrowDefinition(id: 0, head: Cell(x: 2, y: 1), direction: .right, color: .red, length: 2)
        for gates in [[], [GateDefinition(key: arrow.gateKey, color: .green)]] {
            let level = LevelDefinition(id: 1, size: 4, arrows: [arrow], gates: gates)
            XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: [arrow], level: level), .allowed)
            XCTAssertNotNil(LevelValidator.solution(for: level))
        }
        let overlap = ArrowDefinition(id: 1, head: arrow.head, direction: .up, color: .red, length: 1)
        XCTAssertNil(LevelValidator.solution(for: LevelDefinition(id: 1, size: 4, arrows: [arrow, overlap], gates: [GateDefinition(key: arrow.gateKey, color: .red)])))
    }
    func testHintIsLegalAndTutorialStartsWithCollectibleArtwork() throws {
        for level in LevelRepository.levels {
            let hint = try XCTUnwrap(PuzzleRules.hint(remaining: level.arrows, level: level))
            XCTAssertEqual(PuzzleRules.evaluate(hint, remaining: level.arrows, level: level), .allowed)
        }
        let level = LevelRepository.level(1)
        XCTAssertGreaterThanOrEqual(level.arrows.count, 10)
        XCTAssertTrue(level.arrows.allSatisfy { $0.length >= 3 })
        XCTAssertEqual(level.completionArtwork, "EnchantedTreePiece01")
        XCTAssertGreaterThan(Set(level.arrows.map(\.color)).count, 1)
        XCTAssertTrue(level.arrows.allSatisfy { $0.color.hex.hasPrefix("#") })
        XCTAssertEqual(Set(level.arrows.flatMap(\.cells)), Set(try XCTUnwrap(level.activeCells)))
        XCTAssertTrue(level.arrows.contains { PuzzleRules.evaluate($0, remaining: level.arrows, level: level) == .allowed })
        XCTAssertTrue(level.arrows.contains { PuzzleRules.evaluate($0, remaining: level.arrows, level: level) == .blocked })
    }

    func testTargetPixelsRequireAReachableArrowOfTheSameColour() throws {
        let source = LevelRepository.level(1)
        var targets = try XCTUnwrap(source.targetCells)
        targets[0] = TargetCell(cell: targets[0].cell, color: ArrowColor(hex: "#010203"))
        let impossible = LevelDefinition(id: source.id, size: source.size, height: source.height,
                                         timeLimit: source.timeLimit, arrows: source.arrows,
                                         gates: source.gates, difficulty: source.difficulty,
                                         activeCells: source.activeCells, targetCells: targets)
        XCTAssertNil(LevelValidator.solution(for: impossible))
    }
    func testDuplicateMistakesCostOneLifePerArrowAndReset() {
        var tracker = MistakeTracker()
        XCTAssertTrue(tracker.register(arrowID: 10))
        for _ in 0..<10 { XCTAssertFalse(tracker.register(arrowID: 10)) }
        XCTAssertTrue(tracker.register(arrowID: 11))
        XCTAssertTrue(tracker.register(arrowID: 12))
        XCTAssertEqual(tracker.penalized.count, 3)
        tracker.reset()
        XCTAssertTrue(tracker.register(arrowID: 10))
    }
    func testLegacyPortalMetadataIsIgnored() {
        let arrow = ArrowDefinition(id: 0, head: Cell(x: 3, y: 1), direction: .right, color: .blue, length: 1)
        let level = LevelDefinition(id: 1, size: 4, height: 6, arrows: [arrow], gates: [GateDefinition(key: arrow.gateKey, color: .blue, thawAfterMoves: 3)])
        XCTAssertEqual(PuzzleRules.evaluate(arrow, remaining: [arrow], level: level), .allowed)
        XCTAssertEqual(PuzzleRules.hint(remaining: [arrow], level: level)?.id, arrow.id)
        XCTAssertNotNil(LevelValidator.solution(for: level))
        XCTAssertTrue(level.contains(Cell(x: 2, y: 5)))
        XCTAssertFalse(level.contains(Cell(x: 4, y: 5)))
        for level in LevelRepository.levels {
            XCTAssertTrue(level.gates.allSatisfy { $0.thawAfterMoves == 0 })
            XCTAssertNotNil(LevelValidator.solution(for: level))
        }
    }
    func testBentBodiesAndFirstContact() throws {
        let cells = [Cell(x: 3, y: 3), Cell(x: 2, y: 3), Cell(x: 1, y: 3), Cell(x: 1, y: 2), Cell(x: 1, y: 1)]
        let bent = ArrowDefinition(id: 0, head: cells[0], direction: .right, color: .blue, length: 5, body: cells)
        let obstacle = ArrowDefinition(id: 1, head: Cell(x: 5, y: 4), direction: .up, color: .yellow, length: 3)
        let level = LevelDefinition(id: 1, size: 7, arrows: [bent, obstacle], gates: [GateDefinition(key: bent.gateKey, color: .blue), GateDefinition(key: obstacle.gateKey, color: .yellow)])
        XCTAssertEqual(PuzzleRules.blockingCell(bent, remaining: level.arrows, level: level), Cell(x: 5, y: 3))
        XCTAssertEqual(PuzzleRules.evaluate(bent, remaining: level.arrows, level: level), .blocked)
        XCTAssertNotNil(LevelValidator.solution(for: level))
        let malformed = ArrowDefinition(id: 0, head: cells[0], direction: .right, color: .blue, length: 2, body: [cells[0], Cell(x: 1, y: 1)])
        XCTAssertNil(LevelValidator.solution(for: LevelDefinition(id: 1, size: 7, arrows: [malformed], gates: level.gates)))
        let origin = MotionPoint(x: 3, y: 3)
        XCTAssertEqual(ArrowMotion(obstacle).firstIntersection(from: origin, direction: .right), 2)
        let straight = ArrowDefinition(id: 2, head: Cell(x: 6, y: 3), direction: .right, color: .red, length: 2)
        XCTAssertEqual(ArrowMotion(straight).firstIntersection(from: origin, direction: .right)!, 1.7, accuracy: 0.00001)
        let decoded = try JSONDecoder().decode(ArrowDefinition.self, from: JSONEncoder().encode(bent))
        XCTAssertEqual(decoded.cells, cells)
    }
    func testSnakeRibbonKeepsLengthAndRetracesCorners() {
        let cells = [Cell(x: 4, y: 4), Cell(x: 3, y: 4), Cell(x: 2, y: 4), Cell(x: 2, y: 3), Cell(x: 2, y: 2), Cell(x: 3, y: 2)]
        let arrow = ArrowDefinition(id: 0, head: cells[0], direction: .right, color: .green, length: cells.count, body: cells)
        let motion = ArrowMotion(arrow)
        for distance in stride(from: 0.0, through: 12, by: 0.125) {
            let points = motion.points(travel: distance)
            let length = zip(points, points.dropFirst()).reduce(0.0) { sum, pair in sum + hypot(pair.1.x - pair.0.x, pair.1.y - pair.0.y) }
            XCTAssertEqual(length, motion.length, accuracy: 0.00001)
            XCTAssertEqual(points.last!.x, Double(arrow.head.x) + 0.3 + distance, accuracy: 0.00001)
            XCTAssertEqual(points.last!.y, Double(arrow.head.y), accuracy: 0.00001)
        }
        XCTAssertEqual(motion.points(travel: 0), motion.points(travel: -1))
        XCTAssertEqual(motion.points(travel: 10).count, 2)
        XCTAssertEqual(ArrowMotion.slideProgress(0), 0); XCTAssertEqual(ArrowMotion.slideProgress(1), 1)
        let resting = motion.points(travel: 0)
        XCTAssertTrue(resting.contains(MotionPoint(x: 2, y: 2)))
        XCTAssertTrue(resting.contains(MotionPoint(x: 2, y: 4)))
    }
    func testProgressSettingsBestTimesAndResetSurviveReload() throws {
        let name = "ArrowGateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = ProgressStore(defaults: defaults)
        XCTAssertEqual(store.unlocked, 1)
        XCTAssertEqual(store.hints, 3)
        XCTAssertTrue(store.consumeHint())
        XCTAssertEqual(store.hints, 2)
        store.sound = false; store.haptics = false
        store.complete(1, time: 5); store.complete(1, time: 8)
        XCTAssertEqual(defaults.double(forKey: "bestTime.1"), 5)
        XCTAssertEqual(store.completedLevels, [1])
        let loaded = ProgressStore(defaults: defaults)
        XCTAssertEqual(loaded.unlocked, 2); XCTAssertEqual(loaded.completedLevels, [1])
        XCTAssertEqual(loaded.hints, 2)
        loaded.grantHint(2); XCTAssertEqual(loaded.hints, 4)
        XCTAssertFalse(loaded.sound); XCTAssertFalse(loaded.haptics)
        loaded.complete(LevelRepository.count, time: 20); XCTAssertEqual(loaded.unlocked, LevelRepository.count)
        loaded.reset()
        XCTAssertEqual(ProgressStore(defaults: defaults).unlocked, 1)
        XCTAssertTrue(loaded.completedLevels.isEmpty)
        XCTAssertEqual(loaded.hints, 3)
        XCTAssertEqual(defaults.double(forKey: "bestTime.1"), 0)
        XCTAssertFalse(ProgressStore(defaults: defaults).sound)
    }
}

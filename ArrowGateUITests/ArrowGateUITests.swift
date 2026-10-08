import XCTest

final class ArrowGateUITests: XCTestCase {
    struct Point: Decodable, Hashable { let x: Int; let y: Int }
    struct Arrow: Decodable { let id: Int; let head: Point; let direction: Int; let length: Int; let body: [Point]?
        var cells: [Point] { body ?? (0..<length).map { let delta = [(1,0),(0,1),(-1,0),(0,-1)][direction]; return Point(x: head.x - delta.0 * $0, y: head.y - delta.1 * $0) } }
    }
    struct Key: Decodable { let side: Int; let lane: Int }
    struct Gate: Decodable { let key: Key; let thawAfterMoves: Int }
    struct Fixture: Decodable { let number: Int; let size: Int; let height: Int; let gates: [Gate]; let arrows: [Arrow]; let solution: [Int] }
    var app: XCUIApplication!
    let deltas = [(1,0), (0,1), (-1,0), (0,-1)]
    override func setUpWithError() throws {
        continueAfterFailure = false; app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-reset-test-progress", "-skip-board-intro"]
    }
    func fixtures() throws -> [Fixture] {
        let url = try XCTUnwrap(Bundle(for: ArrowGateUITests.self).url(forResource: "levels", withExtension: "json"))
        return try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: url))
    }
    var board: XCUIElement { app.otherElements["board"] }
    var summary: String { board.value as? String ?? "" }
    var lives: String { app.descendants(matching: .any)["lives"].value as? String ?? "" }
    func tapArrow(_ arrow: Arrow, level: Fixture, wait: Bool = true) {
        let frame = board.frame
        let cellSize = 15.0, worldMargin = 44.0
        let scale = max((Double(level.size) * cellSize + worldMargin * 2) / (frame.width - 24),
                        (Double(level.height) * cellSize + worldMargin * 2) / (frame.height - 24))
        let x = 0.5 + ((Double(arrow.head.x) + 0.5) * cellSize - Double(level.size) * cellSize / 2) / (frame.width * scale)
        let y = 0.5 - ((Double(arrow.head.y) + 0.5) * cellSize - Double(level.height) * cellSize / 2) / (frame.height * scale)
        board.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        if wait { Thread.sleep(forTimeInterval: 0.4) }
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func hint() { app.buttons["pause"].tap(); app.buttons["hint"].tap() }
    func isPathClear(_ arrow: Arrow, remaining: [Arrow]? = nil, level: Fixture) -> Bool {
        let occupied = Set((remaining ?? level.arrows).filter { $0.id != arrow.id }.flatMap(\.cells))
        let delta = deltas[arrow.direction]
        var x = arrow.head.x + delta.0, y = arrow.head.y + delta.1
        while x >= 0 && x < level.size && y >= 0 && y < level.height {
            if occupied.contains(Point(x: x, y: y)) { return false }
            x += delta.0; y += delta.1
        }
        return true
    }
    func testCampaignTwentyLevelsThroughRealTouches() throws {
        let levels = try fixtures()
        app.launch(); XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10)); capture("menu")
        app.buttons["play"].tap()
        XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5)); capture("emoji-world-map")
        app.buttons["mapPlay"].tap()
        for level in levels {
            XCTAssertTrue(board.waitForExistence(timeout: 5)); XCTAssertTrue(summary.contains("Level \(level.number);"))
            capture("level-\(level.number)"); hint()
            for id in level.solution { tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level) }
            if level.number < 20 {
                XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '0 mistakes'")).firstMatch.exists)
                if level.number == 1 { capture("victory") }
                app.buttons["nextLevel"].tap()
                XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5))
                app.buttons["mapPlay"].tap()
            } else {
                XCTAssertTrue(app.staticTexts["Gallery complete!"].waitForExistence(timeout: 5)); capture("campaign-complete")
                app.buttons["Open gallery"].tap()
                XCTAssertTrue(app.staticTexts["emojiGallery"].waitForExistence(timeout: 5))
                app.buttons["galleryBack"].tap()
                XCTAssertTrue(app.staticTexts["LEVEL 20 UNLOCKED"].waitForExistence(timeout: 5))
            }
        }
        app.terminate(); app.launchArguments = ["-ui-testing"]; app.launch()
        XCTAssertTrue(app.staticTexts["LEVEL 20 UNLOCKED"].waitForExistence(timeout: 5))
    }
    func testFirstFiveLevelsRevealPaintings() throws {
        let levels = Array(try fixtures().prefix(5))
        let expectedPaintedCells = [69, 61, 61, 61, 61]
        let names = ["painted-happy", "painted-cool", "painted-love", "painted-joy", "painted-angel"]
        for (index, level) in levels.enumerated() {
            app.launchArguments += ["-level", String(level.number)]
            app.launch(); XCTAssertTrue(board.waitForExistence(timeout: 10))
            capture("start-\(names[index])")
            for id in level.solution {
                tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level)
            }
            Thread.sleep(forTimeInterval: 0.85)
            XCTAssertTrue(summary.contains("painted \(expectedPaintedCells[index])"), summary)
            XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 4))
            capture(names[index])
            app.terminate()
            app.launchArguments = ["-ui-testing", "-reset-test-progress", "-skip-board-intro"]
        }
    }
    func testJourneyMapAndGalleryReflectCollectedEmoji() throws {
        let level = try XCTUnwrap(fixtures().first)
        app.launch(); XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        app.buttons["play"].tap()
        XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["0 / 20"].exists); capture("journey-empty")
        app.buttons["galleryTab"].tap()
        XCTAssertTrue(app.staticTexts["emojiGallery"].waitForExistence(timeout: 5)); capture("gallery-empty")
        app.buttons["mapTab"].tap(); app.buttons["mapPlay"].tap()
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        for id in level.solution { tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level) }
        XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 6))
        app.buttons["nextLevel"].tap()
        XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 / 20"].exists); capture("journey-one-collected")
        app.buttons["galleryTab"].tap()
        XCTAssertTrue(app.staticTexts["Happy"].waitForExistence(timeout: 5)); capture("gallery-one-collected")
    }
    func testSmileArtworkMorphsBeforeCompletionCard() throws {
        let level = try XCTUnwrap(fixtures().first)
        app.launchArguments += ["-level", "1"]
        app.launch(); XCTAssertTrue(board.waitForExistence(timeout: 10))
        for id in level.solution {
            tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level)
        }

        // The completed mosaic should have time to become the polished collectible
        // before the result card covers the board.
        Thread.sleep(forTimeInterval: 2.65)
        XCTAssertFalse(app.buttons["nextLevel"].exists)
        capture("smile-artwork-morph")
        XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 3))
        capture("smile-artwork-card")
    }
    func testRapidDependentTapsAndRestartDuringExit() throws {
        let level = try XCTUnwrap(fixtures().first)
        // Slow only the visual motion to prove touches work while other arrows are still exiting.
        app.launchArguments += ["-level", "1", "-test-exit-duration", "3"]
        app.launch(); XCTAssertTrue(board.waitForExistence(timeout: 10))
        for id in level.solution {
            tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level, wait: false)
        }
        XCTAssertTrue(summary.contains("arrows 0")); XCTAssertFalse(summary.contains("pending 0"))
        XCTAssertEqual(lives, "3"); capture("parallel-exits")
        app.buttons["restart"].tap()
        Thread.sleep(forTimeInterval: 3.5)
        XCTAssertTrue(summary.contains("arrows \(level.arrows.count)")); XCTAssertTrue(summary.contains("pending 0"))
        XCTAssertEqual(lives, "3"); XCTAssertFalse(app.buttons["nextLevel"].exists)
        for id in level.solution {
            tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level, wait: false)
        }
        XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '0 mistakes'")).firstMatch.exists)
    }
    func testRepeatedBlockedTapAndWarningRecovery() throws {
        let level = try XCTUnwrap(fixtures().first { fixture in
            fixture.arrows.contains { !isPathClear($0, level: fixture) }
        })
        app.launchArguments += ["-level", String(level.number)]; app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        let blocked = try XCTUnwrap(level.arrows.first { !isPathClear($0, level: level) })
        tapArrow(blocked, level: level)
        XCTAssertEqual(lives, "2"); XCTAssertTrue(summary.contains("warnings 1")); capture("blocked-warning")
        for _ in 0..<3 { tapArrow(blocked, level: level) }
        XCTAssertEqual(lives, "2"); XCTAssertTrue(summary.contains("warnings 1"))
        hint(); XCTAssertTrue(summary.contains("warnings 1"))
        var remaining = level.arrows
        var cleared = false
        for id in level.solution where id != blocked.id {
            let arrow = try XCTUnwrap(remaining.first { $0.id == id })
            tapArrow(arrow, level: level)
            remaining.removeAll { $0.id == id }
            if isPathClear(blocked, remaining: remaining, level: level) {
                cleared = true
                break
            }
        }
        XCTAssertTrue(cleared)
        Thread.sleep(forTimeInterval: 0.2); capture("edge-confetti")
        XCTAssertTrue(summary.contains("warnings 0")); XCTAssertEqual(lives, "2"); capture("warning-cleared")
        tapArrow(blocked, level: level); XCTAssertEqual(lives, "2")
        XCTAssertTrue(summary.contains("arrows \(remaining.count - 1)"))
        app.buttons["restart"].tap(); XCTAssertEqual(lives, "3")
        tapArrow(blocked, level: level); XCTAssertEqual(lives, "2")
    }
    func testCleanBoardIntroductionAndZoomLimits() throws {
        let level = try XCTUnwrap(fixtures().first { $0.number == 17 })
        app.launchArguments.removeAll { $0 == "-skip-board-intro" }
        app.launchArguments += ["-level", "17"]
        app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 1.4)
        XCTAssertFalse(summary.contains("zoom 1.0"), summary)
        capture("clean-centre-focus")
        board.pinch(withScale: 0.1, velocity: -2)
        XCTAssertTrue(summary.contains("zoom 1.0"))
        capture("clean-full-board")
        board.pinch(withScale: 8, velocity: 2)
        XCTAssertTrue(summary.contains("zoom 1.6"))
        board.swipeLeft(); board.swipeUp(); board.swipeRight(); board.swipeDown()
        XCTAssertEqual(lives, "3")
        XCTAssertTrue(summary.contains("arrows \(level.arrows.count)"))
        capture("clean-maximum-zoom")
        app.buttons["pause"].tap(); capture("clean-pause")
        app.buttons["Continue"].tap()
        app.buttons["back"].tap(); capture("clean-menu")
        app.buttons["Settings"].tap(); capture("clean-settings")
    }
    func testDenseBoardZoomPanAndMove() throws {
        let level = try XCTUnwrap(fixtures().last)
        app.launchArguments += ["-level", "20"]; app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10)); XCTAssertTrue(summary.contains("Level 20;"))
        XCTAssertGreaterThanOrEqual(board.frame.minX, app.frame.minX); XCTAssertLessThanOrEqual(board.frame.maxX, app.frame.maxX)
        XCTAssertTrue(summary.contains("zoom 1.0")); capture("dense-overview")
        board.pinch(withScale: 2, velocity: 1)
        XCTAssertFalse(summary.contains("zoom 1.0"))
        let start = board.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5))
        let end = board.coordinate(withNormalizedOffset: CGVector(dx: 0.30, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertEqual(lives, "3"); XCTAssertTrue(summary.contains("arrows \(level.arrows.count)")); capture("dense-zoomed")
        app.buttons["restart"].tap(); XCTAssertTrue(summary.contains("zoom 1.0"))
        hint(); tapArrow(try XCTUnwrap(level.arrows.first { $0.id == level.solution[0] }), level: level)
        XCTAssertTrue(summary.contains("arrows \(level.arrows.count - 1)")); XCTAssertEqual(lives, "3")
    }
    func testDistinctMistakesDefeatPauseRestartSettingsAndMenu() throws {
        let level = try XCTUnwrap(fixtures().last)
        app.launchArguments += ["-level", "20"]; app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10)); app.buttons["pause"].tap()
        XCTAssertTrue(app.staticTexts["Take a breath"].waitForExistence(timeout: 5)); capture("pause")
        app.buttons["Continue"].tap()
        let blocked = Array(level.arrows.filter { !isPathClear($0, level: level) }.prefix(3))
        XCTAssertEqual(blocked.count, 3)
        for arrow in blocked { tapArrow(arrow, level: level) }
        XCTAssertTrue(app.staticTexts["Try a new path"].waitForExistence(timeout: 5)); capture("defeat")
        app.buttons["Try again"].tap(); XCTAssertTrue(board.waitForExistence(timeout: 5)); XCTAssertEqual(lives, "3")
        app.buttons["pause"].tap(); app.buttons["pauseRestart"].tap(); XCTAssertEqual(lives, "3")
        app.buttons["back"].tap(); app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Sound"].waitForExistence(timeout: 5)); capture("settings")
        app.switches["Sound"].tap(); app.buttons["Done"].tap(); app.buttons["Settings"].tap()
        app.buttons["Reset Progress"].tap(); app.buttons["Reset Progress"].firstMatch.tap(); app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["LEVEL 1 UNLOCKED"].waitForExistence(timeout: 5))
    }
    func testMenuProgressAndPreferencesSurviveRelaunch() throws {
        let level = try XCTUnwrap(fixtures().first)
        app.launch()
        XCTAssertTrue(app.buttons["play"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.count, 2)
        app.buttons["play"].tap()
        XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5))
        app.buttons["mapPlay"].tap()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        for id in level.solution { tapArrow(try XCTUnwrap(level.arrows.first { $0.id == id }), level: level) }
        XCTAssertTrue(app.buttons["nextLevel"].waitForExistence(timeout: 5))
        app.buttons["Main menu"].tap()
        XCTAssertTrue(app.staticTexts["LEVEL 2 UNLOCKED"].exists)
        app.buttons["Settings"].tap()
        for name in ["Sound", "Haptics"] {
            app.switches[name].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertEqual(app.switches[name].value as? String, "1")
        }
        app.buttons["Done"].tap()
        app.terminate(); app.launchArguments = ["-ui-testing", "-skip-board-intro"]; app.launch()
        XCTAssertTrue(app.staticTexts["LEVEL 2 UNLOCKED"].waitForExistence(timeout: 10))
        app.buttons["Settings"].tap()
        XCTAssertEqual(app.switches["Sound"].value as? String, "1")
        XCTAssertEqual(app.switches["Haptics"].value as? String, "1")
        app.buttons["Done"].tap(); app.buttons["play"].tap()
        XCTAssertTrue(app.staticTexts["journeyMap"].waitForExistence(timeout: 5))
        app.buttons["mapPlay"].tap()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        XCTAssertTrue(summary.contains("Level 2;"))
    }
    func testTutorialHasNoTimeLimit() {
        app.launchArguments += ["-level", "1"]; app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(identifier: "countdown").matching(NSPredicate(format: "label CONTAINS %@", "∞")).firstMatch.exists)
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(summary.contains("arrows 19")); XCTAssertEqual(lives, "3")
    }
    func testCountdownPausesAndExpires() {
        app.launchArguments += ["-level", "1", "-test-time-limit", "8"]; app.launch()
        XCTAssertTrue(board.waitForExistence(timeout: 10)); app.buttons["pause"].tap()
        XCTAssertTrue(app.staticTexts["Take a breath"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 9)
        XCTAssertTrue(app.staticTexts["Take a breath"].exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Time is up"].waitForExistence(timeout: 10)); capture("timeout")
        app.buttons["Try again"].tap(); XCTAssertTrue(board.waitForExistence(timeout: 5)); XCTAssertEqual(lives, "3")
    }
}

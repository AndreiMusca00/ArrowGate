import Foundation

/// The twenty published levels bundled with the game.
enum LevelRepository {
    static let levels: [LevelDefinition] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let levels = try? JSONDecoder().decode([LevelDefinition].self, from: data),
              levels.map(\.id) == Array(1...20),
              levels.allSatisfy({ LevelValidator.solution(for: $0) != nil }) else {
            preconditionFailure("Missing or invalid bundled levels.json")
        }
        return levels
    }()
    static var count: Int { levels.count }
    static func level(_ number: Int) -> LevelDefinition { levels[min(max(number, 1), count) - 1] }
}

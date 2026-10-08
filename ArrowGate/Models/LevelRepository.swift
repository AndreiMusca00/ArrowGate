import Foundation

/// Published chapters and levels bundled with the game.
enum LevelRepository {
    private static let catalog: GameCatalog = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(GameCatalog.self, from: data),
              catalog.version > 0,
              catalog.chapters.map(\.id) == Array(1...catalog.chapters.count),
              catalog.levels.map(\.id) == Array(1...catalog.levels.count),
              catalog.levels.allSatisfy({ level in
                  catalog.chapters.contains { chapter in
                      chapter.id == level.chapterID && chapter.levelRange.contains(level.id)
                  }
              }),
              catalog.chapters.allSatisfy({ chapter in
                  catalog.levels.filter { $0.chapterID == chapter.id }.count == chapter.levelCount
              }),
              catalog.levels.allSatisfy({ LevelValidator.solution(for: $0) != nil }) else {
            preconditionFailure("Missing or invalid bundled catalog.json")
        }
        return catalog
    }()

    static var version: Int { catalog.version }
    static var chapters: [ChapterDefinition] { catalog.chapters }
    static var levels: [LevelDefinition] { catalog.levels }
    static var count: Int { levels.count }
    static func level(_ number: Int) -> LevelDefinition { levels[min(max(number, 1), count) - 1] }
    static func chapter(_ id: Int) -> ChapterDefinition {
        chapters.first { $0.id == id } ?? chapters[0]
    }
    static func chapter(containing level: Int) -> ChapterDefinition {
        chapters.first { $0.levelRange.contains(level) } ?? chapters[0]
    }
    static func levels(in chapter: ChapterDefinition) -> [LevelDefinition] {
        levels.filter { $0.chapterID == chapter.id }
    }
}

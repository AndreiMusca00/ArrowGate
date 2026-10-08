import Foundation

/// Published chapters and levels bundled with the game.
enum LevelRepository {
    static let chapters: [ChapterDefinition] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "chapters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let chapters = try? JSONDecoder().decode([ChapterDefinition].self, from: data),
              chapters.map(\.id) == Array(1...chapters.count) else {
            preconditionFailure("Missing or invalid bundled chapters.json")
        }
        return chapters
    }()

    static let levels: [LevelDefinition] = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "levels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let levels = try? JSONDecoder().decode([LevelDefinition].self, from: data),
              levels.map(\.id) == Array(1...levels.count),
              levels.allSatisfy({ level in
                  chapters.contains { chapter in chapter.id == level.chapterID && chapter.levelRange.contains(level.id) }
              }),
              levels.allSatisfy({ LevelValidator.solution(for: $0) != nil }) else {
            preconditionFailure("Missing or invalid bundled levels.json")
        }
        return levels
    }()
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

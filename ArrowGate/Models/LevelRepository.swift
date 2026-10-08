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
              catalog.configuration.levelsPerChapter == 50,
              catalog.chapters.map(\.id) == Array(1...catalog.chapters.count),
              catalog.levels.map(\.id) == Array(1...catalog.levels.count),
              catalog.levels.allSatisfy({ level in
                  catalog.chapters.contains { $0.id == level.chapterID }
              }),
              catalog.chapters.allSatisfy({ chapter in
                  chapter.levelCount == catalog.configuration.levelsPerChapter
                      && !catalog.levels.filter({ $0.chapterID == chapter.id }).isEmpty
                      && catalog.levels.filter({ $0.chapterID == chapter.id }).count <= chapter.levelCount
                      && chapter.style.hasValidValues
              }),
              catalog.levels.allSatisfy({ LevelValidator.solution(for: $0) != nil }) else {
            preconditionFailure("Missing or invalid bundled catalog.json")
        }
        return catalog
    }()

    static var version: Int { catalog.version }
    static var levelsPerChapter: Int { catalog.configuration.levelsPerChapter }
    static var chapters: [ChapterDefinition] { catalog.chapters }
    static var levels: [LevelDefinition] { catalog.levels }
    static var count: Int { levels.count }
    static func level(_ number: Int) -> LevelDefinition { levels[min(max(number, 1), count) - 1] }
    static func chapter(_ id: Int) -> ChapterDefinition {
        chapters.first { $0.id == id } ?? chapters[0]
    }
    static func chapter(containing level: Int) -> ChapterDefinition {
        guard let chapterID = levels.first(where: { $0.id == level })?.chapterID else { return chapters[0] }
        return chapter(chapterID)
    }
    static func levels(in chapter: ChapterDefinition) -> [LevelDefinition] {
        levels.filter { $0.chapterID == chapter.id }
    }
    static func firstLevel(in chapter: ChapterDefinition) -> LevelDefinition? {
        levels(in: chapter).first
    }
}

private extension ChapterStyleDefinition {
    var hasValidValues: Bool {
        [primaryColor, secondaryColor, backgroundColor].allSatisfy { color in
            color.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
        }
            && !decorations.isEmpty
            && galleryCardHeight > 0
            && galleryCornerRadius > 0
            && (0...1).contains(detailBackgroundOpacity)
            && mapCornerRadius > 0
            && (0...1).contains(mapBackgroundOpacity)
            && (0...1).contains(mapBorderOpacity)
    }
}

import Foundation

struct CatalogConfiguration: Codable, Equatable {
    let levelsPerChapter: Int
}

/// Small manifest that tells the app which independently published chapter
/// files belong to the current campaign.
struct CatalogIndex: Codable {
    let version: Int
    let configuration: CatalogConfiguration
    let chapterFiles: [String]
}

/// One self-contained chapter payload. Future online updates can replace or
/// add this file without rewriting previously published chapters.
struct ChapterCatalog: Codable {
    let chapter: ChapterDefinition
    let levels: [LevelDefinition]
}

/// Fully assembled in-memory catalog used by the rest of the app.
struct GameCatalog {
    let version: Int
    let configuration: CatalogConfiguration
    let chapters: [ChapterDefinition]
    let levels: [LevelDefinition]
}

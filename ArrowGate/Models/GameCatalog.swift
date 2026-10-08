import Foundation

/// One versioned payload containing everything needed to render the campaign.
/// This is also the shape an online catalog can use later.
struct GameCatalog: Codable {
    let version: Int
    let chapters: [ChapterDefinition]
    let levels: [LevelDefinition]
}

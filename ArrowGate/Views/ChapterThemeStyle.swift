import SwiftUI

struct ChapterThemeStyle {
    let primary: Color
    let secondary: Color
    let background: Color
    let decorations: [String]

    static func style(for theme: ChapterTheme) -> ChapterThemeStyle {
        switch theme {
        case .emoji:
            return ChapterThemeStyle(
                primary: Color(red: 0.91, green: 0.58, blue: 0.12),
                secondary: Color(red: 0.91, green: 0.35, blue: 0.39),
                background: Color(red: 1.00, green: 0.95, blue: 0.82),
                decorations: ["☺︎", "✦", "♡"]
            )
        case .fruit:
            return ChapterThemeStyle(
                primary: Color(red: 0.20, green: 0.58, blue: 0.34),
                secondary: Color(red: 0.91, green: 0.31, blue: 0.24),
                background: Color(red: 0.88, green: 0.96, blue: 0.87),
                decorations: ["🍃", "•", "✦"]
            )
        }
    }
}

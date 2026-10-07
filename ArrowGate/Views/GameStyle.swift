import SwiftUI
import SpriteKit

enum GameStyle {
    static let startingHearts = 3
    static var exitDuration: TimeInterval {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing"), let index = arguments.firstIndex(of: "-test-exit-duration"),
           arguments.count > index + 1, let duration = Double(arguments[index + 1]) { return duration }
        #endif
        return 0.24
    }
    static let rejectDuration = 0.18
    static let selectionScale: CGFloat = 1.04
    static let cellSize: CGFloat = 44
    static let worldMargin: CGFloat = 44
    static let maximumZoom: CGFloat = 3
    static let confettiCount = 10
    static let confettiDuration = 0.26
    static let sceneSize = CGSize(width: 390, height: 700)
    static let background = Color(red: 0.985, green: 0.978, blue: 0.957)
    static let sceneBackground = UIColor(red: 0.985, green: 0.978, blue: 0.957, alpha: 1)
    static let panel = Color.white
    static let ink = Color(red: 0.16, green: 0.22, blue: 0.25)
    static let muted = Color(red: 0.44, green: 0.49, blue: 0.50)
    static let accent = Color(red: 0.04, green: 0.37, blue: 0.39)
    static let guideDot = UIColor(red: 0.67, green: 0.72, blue: 0.72, alpha: 0.65)
    static let portalWell = UIColor(red: 0.14, green: 0.20, blue: 0.23, alpha: 1)
    static let introDuration: TimeInterval = 0.85
    static func uiColor(_ color: ArrowColor) -> UIColor {
        switch color {
        case .yellow: return UIColor(red: 0.73, green: 0.46, blue: 0.04, alpha: 1)
        case .blue: return UIColor(red: 0.30, green: 0.22, blue: 0.43, alpha: 1)
        case .green: return UIColor(red: 0.03, green: 0.37, blue: 0.39, alpha: 1)
        case .red: return UIColor(red: 0.82, green: 0.30, blue: 0.28, alpha: 1)
        }
    }
    static func color(_ color: ArrowColor) -> Color { Color(uiColor: uiColor(color)) }
}

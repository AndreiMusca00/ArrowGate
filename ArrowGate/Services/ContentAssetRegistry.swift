import SwiftUI
import UIKit

/// Resolves downloaded content artwork. The named-image fallback is retained
/// only for generic interface artwork that still belongs to the app bundle.
enum ContentAssetRegistry {
    private static let lock = NSLock()
    private static var remoteURLs: [String: URL] = [:]

    static func install(_ urls: [String: URL]) {
        lock.lock()
        remoteURLs = urls
        lock.unlock()
    }

    static func url(for name: String) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return remoteURLs[name]
    }

    static func uiImage(named name: String) -> UIImage? {
        if let url = url(for: name), let image = UIImage(contentsOfFile: url.path) {
            return image
        }
        return UIImage(named: name)
    }

    static func image(named name: String) -> Image {
        if let image = uiImage(named: name) { return Image(uiImage: image) }
        return Image(name)
    }
}

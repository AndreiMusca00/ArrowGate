import Foundation

protocol ContentTransport: Sendable {
    func fetchData(at path: String, maximumSize: Int64) async throws -> Data
    func downloadFile(at path: String, to destination: URL) async throws
}

/// Reads an unpublished content package copied only into Debug builds. This
/// lets a real iPhone play candidate levels without Firebase or a LAN server.
struct BundleContentTransport: ContentTransport {
    let rootURL: URL

    init?(bundle: Bundle = .main, subdirectory: String = "LocalPreviewContent") {
        guard let resourceURL = bundle.resourceURL else { return nil }
        let root = resourceURL.appendingPathComponent(subdirectory, isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        rootURL = root
    }

    func fetchData(at path: String, maximumSize: Int64) async throws -> Data {
        let data = try Data(contentsOf: url(for: path), options: .mappedIfSafe)
        guard data.count <= maximumSize else { throw RemoteContentError.fileTooLarge(path) }
        return data
    }

    func downloadFile(at path: String, to destination: URL) async throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: url(for: path), to: destination)
    }

    private func url(for path: String) -> URL {
        path.split(separator: "/").reduce(rootURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}

/// Useful for local development and keeps the lifecycle manager independent
/// from Firebase. Production uses FirebaseStorageContentTransport.
struct HTTPContentTransport: ContentTransport {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchData(at path: String, maximumSize: Int64) async throws -> Data {
        let (data, response) = try await session.data(from: url(for: path))
        try Self.validate(response)
        guard data.count <= maximumSize else { throw RemoteContentError.fileTooLarge(path) }
        return data
    }

    func downloadFile(at path: String, to destination: URL) async throws {
        let (temporaryURL, response) = try await session.download(from: url(for: path))
        try Self.validate(response)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private func url(for path: String) -> URL {
        path.split(separator: "/").reduce(baseURL) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

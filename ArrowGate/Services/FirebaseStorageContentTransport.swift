import FirebaseStorage
import Foundation

/// The only Firebase-specific object used by the content system. Keeping this
/// adapter small makes the lifecycle logic testable without Firebase.
final class FirebaseStorageContentTransport: @unchecked Sendable, ContentTransport {
    private let storage: Storage

    init(storage: Storage = .storage()) {
        self.storage = storage
    }

    func fetchData(at path: String, maximumSize: Int64) async throws -> Data {
        try await storage.reference(withPath: path).data(maxSize: maximumSize)
    }

    func downloadFile(at path: String, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            storage.reference(withPath: path).write(toFile: destination) { (result: Result<URL, Error>) in
                switch result {
                case .success: continuation.resume(returning: ())
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}

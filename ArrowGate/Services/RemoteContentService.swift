import Combine
import Foundation

@MainActor
final class RemoteContentService: ObservableObject {
    enum State: Equatable {
        case idle
        case syncing
        case ready(ContentLifecycleSnapshot)
        case offlineUsingLocalContent
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var installedContent: InstalledGameContent?

    private let manager: ContentLifecycleManager
    private var task: Task<Void, Never>?
    private var didAttemptCatalogRefresh = false

    init(manager: ContentLifecycleManager) {
        self.manager = manager
    }

    static func firebaseService(bundle: Bundle = .main) -> RemoteContentService? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        return makeService(
            transport: FirebaseStorageContentTransport(),
            cacheDirectory: "PictarrowContent",
            bundle: bundle
        )
    }

    #if DEBUG
    static func localPreviewService(bundle: Bundle = .main) -> RemoteContentService? {
        guard let transport = BundleContentTransport(bundle: bundle) else { return nil }
        return makeService(
            transport: transport,
            cacheDirectory: "PictarrowPreviewContent",
            bundle: bundle
        )
    }
    #endif

    private static func makeService(
        transport: any ContentTransport,
        cacheDirectory: String,
        bundle: Bundle
    ) -> RemoteContentService? {
        do {
            let root = try ContentLifecycleManager.defaultRootURL(directoryName: cacheDirectory)
            let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            let manager = try ContentLifecycleManager(
                transport: transport,
                rootURL: root,
                currentAppVersion: version,
                bundledChapterIDs: []
            )
            return RemoteContentService(manager: manager)
        } catch {
            return nil
        }
    }

    func synchronize(
        unlockedLevel: Int,
        completedChapterIDs: Set<Int>,
        completedEventIDs: Set<String>,
        forceCatalogRefresh: Bool = false
    ) {
        task?.cancel()
        if forceCatalogRefresh { didAttemptCatalogRefresh = false }
        state = .syncing
        task = Task { [manager] in
            do {
                if !didAttemptCatalogRefresh {
                    didAttemptCatalogRefresh = true
                    _ = try? await manager.refreshCatalog()
                }
                guard !Task.isCancelled else { return }
                let snapshot = try await manager.reconcile(
                    unlockedLevel: unlockedLevel,
                    completedChapterIDs: completedChapterIDs,
                    completedEventIDs: completedEventIDs
                )
                guard !Task.isCancelled else { return }
                installedContent = try await manager.installedGameContent()
                state = .ready(snapshot)
            } catch is CancellationError {
                return
            } catch {
                // A future launch retries automatically. Returning players can
                // still activate their previously validated downloaded files.
                state = .offlineUsingLocalContent
            }
        }
    }

    deinit { task?.cancel() }
}

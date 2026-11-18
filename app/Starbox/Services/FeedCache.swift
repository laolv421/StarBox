import Foundation

final class FeedCache: @unchecked Sendable {
    static let shared = FeedCache()

    private let fileURL: URL
    private let metaKey = "cachedGeneratedAt"
    private let cacheVersionKey = "feedCacheVersion"
    private let currentCacheVersion = 2

    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("starbox-feed-payload.json")
        migrateIfNeeded()
    }

    func save(_ payload: FeedPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            UserDefaults.standard.set(payload.meta.generatedAt, forKey: metaKey)
            UserDefaults.standard.set(currentCacheVersion, forKey: cacheVersionKey)
        } catch {
            // Non-fatal
        }
    }

    func load() -> FeedPayload? {
        guard UserDefaults.standard.integer(forKey: cacheVersionKey) >= currentCacheVersion else {
            return nil
        }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let payload = try? JSONDecoder().decode(FeedPayload.self, from: data) else {
            return nil
        }
        // Ignore caches that never got trend lists — force a network refresh path.
        if payload.trends == nil || ((payload.trends?.week.isEmpty ?? true)
            && (payload.trends?.month.isEmpty ?? true)
            && (payload.trends?.all.isEmpty ?? true)) {
            return nil
        }
        return payload
    }

    func cachedGeneratedAt() -> String? {
        UserDefaults.standard.string(forKey: metaKey)
    }

    private func migrateIfNeeded() {
        let version = UserDefaults.standard.integer(forKey: cacheVersionKey)
        if version < currentCacheVersion {
            try? FileManager.default.removeItem(at: fileURL)
            UserDefaults.standard.removeObject(forKey: metaKey)
            UserDefaults.standard.set(currentCacheVersion, forKey: cacheVersionKey)
        }
    }
}

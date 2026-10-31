import Foundation

final class FeedCache: @unchecked Sendable {
    static let shared = FeedCache()

    private let fileURL: URL
    private let metaKey = "cachedGeneratedAt"

    init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("starbox-feed-payload.json")
    }

    func save(_ payload: FeedPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
            UserDefaults.standard.set(payload.meta.generatedAt, forKey: metaKey)
        } catch {
            // Non-fatal
        }
    }

    func load() -> FeedPayload? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(FeedPayload.self, from: data)
    }

    func cachedGeneratedAt() -> String? {
        UserDefaults.standard.string(forKey: metaKey)
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class FeedStore {
    private(set) var items: [RepoItem] = []
    private(set) var categories: [CategoryDTO] = []
    private(set) var meta: MetaResponse?
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var usedCache = false
    private(set) var usedBundle = false

    private let client: FeedClient
    private let cache: FeedCache

    init(client: FeedClient = .shared, cache: FeedCache = .shared) {
        self.client = client
        self.cache = cache
    }

    var generatedAtLabel: String {
        guard let raw = meta?.generatedAt ?? cache.cachedGeneratedAt() else {
            return "尚未加载数据"
        }
        return Self.relativeZh(fromISO: raw)
    }

    var discoverItems: [RepoItem] {
        let trending = items.filter(\.isTrending)
        if trending.count >= 8 { return trending }
        return Array(items.sorted { $0.stars > $1.stars }.prefix(40))
    }

    var toolboxItems: [RepoItem] {
        items.filter { $0.source == "curated" }
    }

    var scenes: [String] {
        let set = Set(toolboxItems.compactMap(\.scene))
        return set.sorted()
    }

    func items(inCategory id: String) -> [RepoItem] {
        items.filter { $0.categoryIds.contains(id) }
    }

    func item(id: String) -> RepoItem? {
        items.first { $0.id == id }
    }

    func load(forceNetwork: Bool = false) async {
        if isLoading { return }
        isLoading = true
        lastError = nil
        usedCache = false
        usedBundle = false
        defer { isLoading = false }

        // Show something immediately when opening the app offline.
        if items.isEmpty {
            if let cached = cache.load() {
                apply(cached)
                usedCache = true
            } else if let bundled = client.loadBundled() {
                apply(bundled)
                usedBundle = true
            }
        }

        do {
            let payload = try await client.fetchAll()
            apply(payload)
            cache.save(payload)
            usedCache = false
            usedBundle = false
            lastError = nil
        } catch {
            if items.isEmpty {
                lastError = error.localizedDescription
            } else if forceNetwork || usedBundle {
                lastError = usedBundle
                    ? "离线演示数据（部署 Pages 后可自动更新）"
                    : "网络更新失败，已显示缓存"
            } else {
                usedCache = true
                lastError = forceNetwork ? "网络更新失败，已显示缓存" : nil
            }
        }
    }

    private func apply(_ payload: FeedPayload) {
        items = payload.feed.items
        categories = payload.categories.categories
        meta = payload.meta
    }

    private static func relativeZh(fromISO raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: raw)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: raw)
        }
        guard let date else { return "更新于 \(raw)" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "刚刚更新" }
        if seconds < 3600 { return "\(seconds / 60) 分钟前更新" }
        if seconds < 86_400 { return "\(seconds / 3600) 小时前更新" }
        return "\(seconds / 86_400) 天前更新"
    }
}

struct FeedPayload: Codable, Sendable {
    var feed: FeedResponse
    var categories: CategoriesResponse
    var meta: MetaResponse
}

import Foundation
import Observation

@MainActor
@Observable
final class FeedStore {
    private(set) var items: [RepoItem] = []
    private(set) var categories: [CategoryDTO] = []
    private(set) var trends: TrendsResponse = .empty
    private(set) var meta: MetaResponse?
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var usedCache = false
    private(set) var usedBundle = false
    private(set) var lastNetworkAt: Date?

    var selectedTrend: TrendPeriod = .week

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

    var refreshHintMinutes: Int {
        meta?.refreshHintMinutes ?? 60
    }

    var needsTimelyRefresh: Bool {
        guard let raw = meta?.generatedAt else { return true }
        guard let date = Self.parseISO(raw) else { return true }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        return minutes >= refreshHintMinutes
    }

    var hasTrendLists: Bool {
        !trends.week.isEmpty || !trends.month.isEmpty || !trends.all.isEmpty
    }

    func discoverItems(for period: TrendPeriod) -> [RepoItem] {
        let list = trends.items(for: period)
        if !list.isEmpty { return list }

        // Fallback when trends.json missing: keep three tabs visually distinct
        let ranked = items.sorted { $0.stars > $1.stars }
        guard !ranked.isEmpty else { return [] }
        switch period {
        case .week:
            let weekly = items.filter { $0.starsDelta7d > 0 || $0.trendPeriods.contains("week") }
            if weekly.count >= 5 {
                return weekly.sorted { $0.starsDelta7d > $1.starsDelta7d }
            }
            // Mid slice — rising / mid-tier, not the all-time top
            let start = min(ranked.count / 3, max(ranked.count - 12, 0))
            return Array(ranked[start..<min(start + 12, ranked.count)])
        case .month:
            let monthly = items.filter { $0.starsDelta30d > 0 || $0.trendPeriods.contains("month") }
            if monthly.count >= 5 {
                return monthly.sorted { $0.starsDelta30d > $1.starsDelta30d }
            }
            let start = min(ranked.count / 5, max(ranked.count - 20, 0))
            return Array(ranked[start..<min(start + 20, ranked.count)])
        case .all:
            return Array(ranked.prefix(40))
        }
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
        if let hit = items.first(where: { $0.id == id }) { return hit }
        for period in TrendPeriod.allCases {
            if let hit = trends.items(for: period).first(where: { $0.id == id }) {
                return hit
            }
        }
        return nil
    }

    func load(forceNetwork: Bool = false) async {
        if isLoading { return }
        isLoading = true
        lastError = nil
        usedCache = false
        usedBundle = false
        defer { isLoading = false }

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
            lastNetworkAt = Date()
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

    /// Refresh when opening Discover if data is stale or trend lists are missing.
    func refreshIfStale() async {
        if needsTimelyRefresh || !hasTrendLists {
            await load(forceNetwork: true)
        }
    }

    private func apply(_ payload: FeedPayload) {
        items = payload.feed.items
        categories = payload.categories.categories
        trends = payload.trends ?? .empty
        meta = payload.meta
    }

    private static func parseISO(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    private static func relativeZh(fromISO raw: String) -> String {
        guard let date = parseISO(raw) else { return "更新于 \(raw)" }
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
    var trends: TrendsResponse?
}

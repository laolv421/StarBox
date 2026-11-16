import Foundation

enum TrendPeriod: String, CaseIterable, Identifiable, Sendable {
    case week
    case month
    case all

    var id: String { rawValue }

    var titleZh: String {
        switch self {
        case .week: return "周趋势"
        case .month: return "月趋势"
        case .all: return "总趋势"
        }
    }

    var subtitleZh: String {
        switch self {
        case .week: return "近 7 天正在变热的项目"
        case .month: return "近 30 天持续升温的项目"
        case .all: return "长期最受欢迎的项目"
        }
    }

    var heatLabel: String {
        switch self {
        case .week: return "本周热度"
        case .month: return "本月热度"
        case .all: return "综合热度"
        }
    }
}

struct MetaResponse: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let itemCount: Int
    let source: String?
    let trendCounts: TrendCounts?
    let refreshHintMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case itemCount = "item_count"
        case source
        case trendCounts = "trend_counts"
        case refreshHintMinutes = "refresh_hint_minutes"
    }
}

struct TrendCounts: Codable, Sendable {
    let week: Int?
    let month: Int?
    let all: Int?
}

struct CategoriesResponse: Codable, Sendable {
    let schemaVersion: Int
    let categories: [CategoryDTO]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case categories
    }
}

struct CategoryDTO: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let nameZh: String
    let subtitleZh: String
    let icon: String

    enum CodingKeys: String, CodingKey {
        case id
        case nameZh = "name_zh"
        case subtitleZh = "subtitle_zh"
        case icon
    }
}

struct FeedResponse: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let items: [RepoItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case items
    }
}

struct TrendsResponse: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let week: [RepoItem]
    let month: [RepoItem]
    let all: [RepoItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case week
        case month
        case all
    }

    func items(for period: TrendPeriod) -> [RepoItem] {
        switch period {
        case .week: return week
        case .month: return month
        case .all: return all
        }
    }

    static let empty = TrendsResponse(
        schemaVersion: 1,
        generatedAt: "",
        week: [],
        month: [],
        all: []
    )
}

struct RepoItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let fullName: String
    let name: String
    let titleZh: String
    let summaryZh: String
    let bulletsZh: [String]
    let categoryIds: [String]
    let topics: [String]
    let stars: Int
    let starsDelta7d: Int
    let starsDelta30d: Int
    let forks: Int
    let language: String?
    let homepage: String?
    let htmlUrl: String
    let avatarUrl: String?
    let description: String?
    let source: String
    let scene: String?
    let trendPeriods: [String]
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case name
        case titleZh = "title_zh"
        case summaryZh = "summary_zh"
        case bulletsZh = "bullets_zh"
        case categoryIds = "category_ids"
        case topics
        case stars
        case starsDelta7d = "stars_delta_7d"
        case starsDelta30d = "stars_delta_30d"
        case forks
        case language
        case homepage
        case htmlUrl = "html_url"
        case avatarUrl = "avatar_url"
        case description
        case source
        case scene
        case trendPeriods = "trend_periods"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fullName = try c.decode(String.self, forKey: .fullName)
        name = try c.decode(String.self, forKey: .name)
        titleZh = try c.decode(String.self, forKey: .titleZh)
        summaryZh = try c.decode(String.self, forKey: .summaryZh)
        bulletsZh = try c.decodeIfPresent([String].self, forKey: .bulletsZh) ?? []
        categoryIds = try c.decodeIfPresent([String].self, forKey: .categoryIds) ?? []
        topics = try c.decodeIfPresent([String].self, forKey: .topics) ?? []
        stars = try c.decodeIfPresent(Int.self, forKey: .stars) ?? 0
        starsDelta7d = try c.decodeIfPresent(Int.self, forKey: .starsDelta7d) ?? 0
        starsDelta30d = try c.decodeIfPresent(Int.self, forKey: .starsDelta30d) ?? 0
        forks = try c.decodeIfPresent(Int.self, forKey: .forks) ?? 0
        language = try c.decodeIfPresent(String.self, forKey: .language)
        homepage = try c.decodeIfPresent(String.self, forKey: .homepage)
        htmlUrl = try c.decode(String.self, forKey: .htmlUrl)
        avatarUrl = try c.decodeIfPresent(String.self, forKey: .avatarUrl)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "trending"
        scene = try c.decodeIfPresent(String.self, forKey: .scene)
        trendPeriods = try c.decodeIfPresent([String].self, forKey: .trendPeriods) ?? []
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(name, forKey: .name)
        try c.encode(titleZh, forKey: .titleZh)
        try c.encode(summaryZh, forKey: .summaryZh)
        try c.encode(bulletsZh, forKey: .bulletsZh)
        try c.encode(categoryIds, forKey: .categoryIds)
        try c.encode(topics, forKey: .topics)
        try c.encode(stars, forKey: .stars)
        try c.encode(starsDelta7d, forKey: .starsDelta7d)
        try c.encode(starsDelta30d, forKey: .starsDelta30d)
        try c.encode(forks, forKey: .forks)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encodeIfPresent(homepage, forKey: .homepage)
        try c.encode(htmlUrl, forKey: .htmlUrl)
        try c.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encode(source, forKey: .source)
        try c.encodeIfPresent(scene, forKey: .scene)
        try c.encode(trendPeriods, forKey: .trendPeriods)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    var isTrending: Bool {
        source == "trending" || !trendPeriods.isEmpty || starsDelta7d > 0 || starsDelta30d > 0
    }

    var starsLabel: String {
        if stars >= 1000 {
            let k = Double(stars) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(stars)"
    }

    func heatPlainZh(for period: TrendPeriod = .week) -> String {
        switch period {
        case .week:
            if starsDelta7d > 50 { return "本周很多人在关注" }
            if starsDelta7d > 0 { return "本周正在升温" }
        case .month:
            if starsDelta30d > 100 { return "本月热度很高" }
            if starsDelta30d > 0 { return "本月持续升温" }
        case .all:
            if stars >= 50_000 { return "长期超级受欢迎" }
            if stars >= 10_000 { return "长期很受欢迎" }
            if stars >= 1000 { return "综合关注度不错" }
        }
        if stars == 0 { return "数据待刷新" }
        return "值得一看"
    }

    /// Backward-compatible helper used outside Discover.
    var heatPlainZh: String { heatPlainZh(for: .week) }
}

import Foundation

struct MetaResponse: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: String
    let itemCount: Int
    let source: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case generatedAt = "generated_at"
        case itemCount = "item_count"
        case source
    }
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
    let forks: Int
    let language: String?
    let homepage: String?
    let htmlUrl: String
    let avatarUrl: String?
    let description: String?
    let source: String
    let scene: String?
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
        case forks
        case language
        case homepage
        case htmlUrl = "html_url"
        case avatarUrl = "avatar_url"
        case description
        case source
        case scene
        case updatedAt = "updated_at"
    }

    var isTrending: Bool { source == "trending" || starsDelta7d > 0 }

    var starsLabel: String {
        if stars >= 1000 {
            let k = Double(stars) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(stars)"
    }

    var heatPlainZh: String {
        if starsDelta7d > 50 {
            return "最近很多人在关注"
        }
        if stars >= 10_000 {
            return "已经很受欢迎"
        }
        if stars >= 1000 {
            return "关注度不错"
        }
        if stars == 0 {
            return "数据待刷新"
        }
        return "值得一看"
    }
}

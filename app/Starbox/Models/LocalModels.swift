import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var repoId: String
    var fullName: String
    var titleZh: String
    var summaryZh: String
    var avatarUrl: String?
    var htmlUrl: String
    var savedAt: Date

    init(from item: RepoItem) {
        self.repoId = item.id
        self.fullName = item.fullName
        self.titleZh = item.titleZh
        self.summaryZh = item.summaryZh
        self.avatarUrl = item.avatarUrl
        self.htmlUrl = item.htmlUrl
        self.savedAt = Date()
    }
}

@Model
final class HistoryItem {
    @Attribute(.unique) var repoId: String
    var fullName: String
    var titleZh: String
    var summaryZh: String
    var avatarUrl: String?
    var viewedAt: Date

    init(from item: RepoItem) {
        self.repoId = item.id
        self.fullName = item.fullName
        self.titleZh = item.titleZh
        self.summaryZh = item.summaryZh
        self.avatarUrl = item.avatarUrl
        self.viewedAt = Date()
    }
}

import SwiftUI
import SwiftData

struct MeView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteItem.savedAt, order: .reverse) private var favorites: [FavoriteItem]
    @Query(sort: \HistoryItem.viewedAt, order: .reverse) private var history: [HistoryItem]
    @State private var feedBaseURL = UserDefaults.standard.string(forKey: "feedBaseURL") ?? ""

    var body: some View {
        NavigationStack {
            List {
                Section("数据") {
                    LabeledContent("内容更新", value: store.generatedAtLabel)
                    LabeledContent("条目数量", value: "\(store.items.count)")
                    if store.isLoading {
                        HStack {
                            ProgressView()
                            Text("正在刷新…")
                                .foregroundStyle(StarboxTheme.muted)
                        }
                    } else {
                        Button("立即刷新") {
                            Task { await store.load(forceNetwork: true) }
                        }
                    }
                }

                Section("收藏") {
                    if favorites.isEmpty {
                        Text("点进工具详情页，点右上角星星即可收藏。收藏只存在本机。")
                            .font(.subheadline)
                            .foregroundStyle(StarboxTheme.muted)
                    } else {
                        ForEach(favorites) { fav in
                            if let item = store.item(id: fav.repoId) {
                                NavigationLink(value: item) {
                                    localRow(title: fav.titleZh, subtitle: fav.summaryZh)
                                }
                            } else {
                                Link(destination: URL(string: fav.htmlUrl)!) {
                                    localRow(title: fav.titleZh, subtitle: fav.summaryZh)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                modelContext.delete(favorites[index])
                            }
                        }
                    }
                }

                Section("最近浏览") {
                    if history.isEmpty {
                        Text("还没有浏览记录")
                            .foregroundStyle(StarboxTheme.muted)
                    } else {
                        ForEach(history.prefix(20)) { row in
                            if let item = store.item(id: row.repoId) {
                                NavigationLink(value: item) {
                                    localRow(title: row.titleZh, subtitle: row.summaryZh)
                                }
                            } else {
                                localRow(title: row.titleZh, subtitle: row.summaryZh)
                            }
                        }
                    }
                }

                Section("数据源地址") {
                    TextField("https://…/starbox/v1", text: $feedBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button("保存并刷新") {
                        let trimmed = feedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            UserDefaults.standard.removeObject(forKey: "feedBaseURL")
                        } else {
                            UserDefaults.standard.set(trimmed, forKey: "feedBaseURL")
                        }
                        Task { await store.load(forceNetwork: true) }
                    }
                    Text("部署 GitHub Pages 后，把静态站的 `/v1` 地址填在这里。默认会尝试读取公开 Pages。")
                        .font(.caption)
                        .foregroundStyle(StarboxTheme.muted)
                }

                Section("关于星盒") {
                    Text("星盒把 GitHub 上好用的开源工具，翻译成普通人能懂的话。数据由定时任务更新，不自建服务器；收藏与浏览记录只保存在你的手机上。")
                        .font(.subheadline)
                        .foregroundStyle(StarboxTheme.muted)
                    LabeledContent("版本", value: "1.0.0")
                }
            }
            .navigationTitle("我的")
            .navigationDestination(for: RepoItem.self) { item in
                RepoDetailView(item: item)
            }
        }
    }

    private func localRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(StarboxTheme.muted)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

import SwiftUI
import SwiftData
import UIKit

struct MeView: View {
    @Environment(FeedStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteItem.savedAt, order: .reverse) private var favorites: [FavoriteItem]
    @Query(sort: \HistoryItem.viewedAt, order: .reverse) private var history: [HistoryItem]
    @State private var feedBaseURL = UserDefaults.standard.string(forKey: "feedBaseURL")
        ?? "https://laolv421.github.io/StarBox/v1"
    @State private var saveMessage: String?
    @State private var justSaved = false
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("数据") {
                    LabeledContent("内容更新", value: store.generatedAtLabel)
                    LabeledContent("条目数量", value: "\(store.items.count)")
                    if let err = store.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        urlFieldFocused = false
                        Task { await store.load(forceNetwork: true) }
                    } label: {
                        if store.isLoading {
                            HStack {
                                ProgressView()
                                Text("正在刷新…")
                            }
                        } else {
                            Text("立即刷新")
                        }
                    }
                    .disabled(store.isLoading)
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
                            } else if let url = URL(string: fav.htmlUrl) {
                                Link(destination: url) {
                                    localRow(title: fav.titleZh, subtitle: fav.summaryZh)
                                }
                            } else {
                                localRow(title: fav.titleZh, subtitle: fav.summaryZh)
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

                Section {
                    TextField("https://…/StarBox/v1", text: $feedBaseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .focused($urlFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { saveAndRefresh() }

                    Button {
                        saveAndRefresh()
                    } label: {
                        HStack(spacing: 8) {
                            if store.isLoading {
                                ProgressView()
                                    .tint(.white)
                                Text("正在刷新…")
                            } else if justSaved {
                                Image(systemName: "checkmark.circle.fill")
                                Text(saveMessage ?? "已保存")
                            } else {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                Text("保存并刷新")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(justSaved ? .green : StarboxTheme.accent)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .disabled(store.isLoading)
                    .animation(.easeInOut(duration: 0.2), value: justSaved)
                    .animation(.easeInOut(duration: 0.2), value: store.isLoading)
                    .sensoryFeedback(.success, trigger: justSaved)

                    if let saveMessage, !justSaved || store.isLoading {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(StarboxTheme.muted)
                    }

                    Text("填写 GitHub Pages 的 `/v1` 地址，例如 https://laolv421.github.io/StarBox/v1")
                        .font(.caption)
                        .foregroundStyle(StarboxTheme.muted)
                } header: {
                    Text("数据源地址")
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
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        urlFieldFocused = false
                    }
                }
            }
        }
    }

    private func saveAndRefresh() {
        urlFieldFocused = false
        justSaved = false
        let trimmed = feedBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        feedBaseURL = trimmed
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: "feedBaseURL")
            saveMessage = "已恢复默认地址，正在刷新…"
        } else if URL(string: trimmed) == nil {
            saveMessage = "地址格式不对，请检查后重试"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        } else {
            UserDefaults.standard.set(trimmed, forKey: "feedBaseURL")
            saveMessage = "已保存，正在刷新…"
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            await store.load(forceNetwork: true)
            if let err = store.lastError {
                saveMessage = err
                justSaved = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                saveMessage = "刷新成功 · \(store.items.count) 条"
                justSaved = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                justSaved = false
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

import SwiftUI

struct CategoriesView: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatusBanner()
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("按生活场景逛") {
                    ForEach(store.categories) { category in
                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.icon)
                                    .font(.title3)
                                    .foregroundStyle(StarboxTheme.accent)
                                    .frame(width: 36, height: 36)
                                    .background(StarboxTheme.softBlue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.nameZh)
                                        .font(.headline)
                                    Text(category.subtitleZh)
                                        .font(.caption)
                                        .foregroundStyle(StarboxTheme.muted)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("分类")
            .refreshable { await store.load(forceNetwork: true) }
        }
    }
}

struct CategoryDetailView: View {
    @Environment(FeedStore.self) private var store
    let category: CategoryDTO

    private var items: [RepoItem] {
        store.items(inCategory: category.id)
    }

    var body: some View {
        List {
            Section {
                Text(category.subtitleZh)
                    .font(.subheadline)
                    .foregroundStyle(StarboxTheme.muted)
            }
            ForEach(items) { item in
                NavigationLink(value: item) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.titleZh).font(.headline)
                        Text(item.summaryZh)
                            .font(.caption)
                            .foregroundStyle(StarboxTheme.muted)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(category.nameZh)
        .navigationDestination(for: RepoItem.self) { item in
            RepoDetailView(item: item)
        }
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("这个分类还空着", systemImage: "tray", description: Text("下拉刷新试试，或先去「工具盒」看看"))
            }
        }
    }
}

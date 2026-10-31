import SwiftUI

struct DiscoverView: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    StatusBanner()
                    LazyVStack(spacing: 12) {
                        ForEach(store.discoverItems) { item in
                            NavigationLink(value: item) {
                                RepoCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(background)
            .navigationTitle("发现")
            .navigationDestination(for: RepoItem.self) { item in
                RepoDetailView(item: item)
            }
            .refreshable {
                await store.load(forceNetwork: true)
            }
            .overlay {
                if store.isLoading && store.items.isEmpty {
                    ProgressView("正在装盒…")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("星盒")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(StarboxTheme.ink)
            Text("普通人也能看懂的 GitHub 好工具与趋势")
                .font(.subheadline)
                .foregroundStyle(StarboxTheme.muted)
        }
        .padding(.top, 4)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                StarboxTheme.softBlue.opacity(0.9),
                StarboxTheme.paper,
                StarboxTheme.softAmber.opacity(0.35),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

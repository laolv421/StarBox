import SwiftUI

struct DiscoverView: View {
    @Environment(FeedStore.self) private var store

    private var period: TrendPeriod {
        store.selectedTrend
    }

    private var items: [RepoItem] {
        store.discoverItems(for: period)
    }

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    StatusBanner()

                    Picker("趋势时段", selection: $store.selectedTrend) {
                        ForEach(TrendPeriod.allCases) { period in
                            Text(period.titleZh).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(period.subtitleZh)
                        .font(.caption)
                        .foregroundStyle(StarboxTheme.muted)

                    LazyVStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(value: item) {
                                RepoCardView(item: item, period: period, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if items.isEmpty, !store.isLoading {
                        ContentUnavailableView(
                            "暂时还没有\(period.titleZh)",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("下拉刷新试试，或稍后再来")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
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
            .task {
                await store.refreshIfStale()
            }
            .overlay {
                if store.isLoading && items.isEmpty {
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
            Text("及时刷新的 GitHub 好工具与趋势")
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

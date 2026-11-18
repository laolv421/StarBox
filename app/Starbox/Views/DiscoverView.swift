import SwiftUI

struct DiscoverView: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let period = store.selectedTrend
        let items = store.discoverItems(for: period)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    StatusBanner()

                    Picker("趋势时段", selection: $store.selectedTrend) {
                        ForEach(TrendPeriod.allCases) { p in
                            Text(p.titleZh).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(period.subtitleZh)
                        Spacer()
                        Text("\(items.count) 个")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(StarboxTheme.muted)

                    if !store.hasTrendLists {
                        Text("尚未拉到分时段趋势，正在用备用列表；请下拉刷新。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    LazyVStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            NavigationLink(value: item) {
                                RepoCardView(item: item, period: period, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                            .id("\(period.rawValue)-\(item.id)-\(index)")
                        }
                    }
                    .id(period)

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
            Text("周 / 月 / 总趋势分开看，下拉可及时刷新")
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

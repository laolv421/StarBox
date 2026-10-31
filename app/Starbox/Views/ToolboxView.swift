import SwiftUI

struct ToolboxView: View {
    @Environment(FeedStore.self) private var store
    @State private var selectedScene: String? = nil

    private var filtered: [RepoItem] {
        guard let selectedScene else { return store.toolboxItems }
        return store.toolboxItems.filter { $0.scene == selectedScene }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("精选好用、长期值得收藏的开源工具。按「我想做什么」筛选即可。")
                        .font(.subheadline)
                        .foregroundStyle(StarboxTheme.muted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            sceneChip(title: "全部", scene: nil)
                            ForEach(store.scenes, id: \.self) { scene in
                                sceneChip(title: scene, scene: scene)
                            }
                        }
                    }

                    StatusBanner()

                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { item in
                            NavigationLink(value: item) {
                                RepoCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(StarboxTheme.paper.ignoresSafeArea())
            .navigationTitle("工具盒")
            .navigationDestination(for: RepoItem.self) { item in
                RepoDetailView(item: item)
            }
            .refreshable { await store.load(forceNetwork: true) }
        }
    }

    private func sceneChip(title: String, scene: String?) -> some View {
        let selected = selectedScene == scene
        return Button {
            selectedScene = scene
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? StarboxTheme.accent : StarboxTheme.card)
                .foregroundStyle(selected ? Color.white : StarboxTheme.ink)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

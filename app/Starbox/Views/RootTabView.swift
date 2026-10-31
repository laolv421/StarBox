import SwiftUI

struct RootTabView: View {
    @State private var store = FeedStore()

    var body: some View {
        TabView {
            DiscoverView()
                .tabItem { Label("发现", systemImage: "sparkle.magnifyingglass") }

            CategoriesView()
                .tabItem { Label("分类", systemImage: "square.grid.2x2") }

            ToolboxView()
                .tabItem { Label("工具盒", systemImage: "shippingbox") }

            MeView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(StarboxTheme.accent)
        .environment(store)
        .task {
            await store.load()
        }
    }
}

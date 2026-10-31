import SwiftUI

struct StatusBanner: View {
    @Environment(FeedStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.generatedAtLabel)
                .font(.caption)
                .foregroundStyle(StarboxTheme.muted)
            if let err = store.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if store.usedBundle {
                Text("当前为内置演示数据")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if store.usedCache {
                Text("已显示本地缓存")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

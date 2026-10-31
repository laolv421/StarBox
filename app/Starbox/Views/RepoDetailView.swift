import SwiftUI
import SwiftData
import SafariServices

struct RepoDetailView: View {
    let item: RepoItem
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteItem]
    @State private var safariURL: IdentifiedURL?

    private var isFavorite: Bool {
        favorites.contains { $0.repoId == item.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                summaryCard
                bulletsCard
                heatCard
                actions
            }
            .padding(16)
        }
        .background(StarboxTheme.paper.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(StarboxTheme.warm)
                }
                .accessibilityLabel(isFavorite ? "取消收藏" : "收藏")
            }
        }
        .onAppear { recordHistory() }
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if let raw = item.avatarUrl, let url = URL(string: raw) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            Color(StarboxTheme.softBlue)
                        }
                    }
                } else {
                    StarboxTheme.softBlue
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.titleZh)
                    .font(.title2.bold())
                    .foregroundStyle(StarboxTheme.ink)
                Text(item.fullName)
                    .font(.caption)
                    .foregroundStyle(StarboxTheme.muted)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一句话")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StarboxTheme.accent)
            Text(item.summaryZh)
                .font(.body)
                .foregroundStyle(StarboxTheme.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StarboxTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var bulletsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("它能帮你做什么")
                .font(.headline)
            ForEach(Array(item.bulletsZh.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(StarboxTheme.accent)
                    Text(bullet)
                        .font(.subheadline)
                        .foregroundStyle(StarboxTheme.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StarboxTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var heatCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("热度")
                .font(.headline)
            Text(item.heatPlainZh)
                .font(.title3.weight(.semibold))
                .foregroundStyle(StarboxTheme.warm)
            Text("约 \(item.stars) 个星标 · \(item.forks) 次派生")
                .font(.caption)
                .foregroundStyle(StarboxTheme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StarboxTheme.softAmber.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let homepage = item.homepage, let url = URL(string: homepage), !homepage.isEmpty {
                Button {
                    safariURL = IdentifiedURL(url: url)
                } label: {
                    Label("打开项目主页", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(StarboxTheme.accent)
            }

            if let url = URL(string: item.htmlUrl) {
                Button {
                    safariURL = IdentifiedURL(url: url)
                } label: {
                    Label("在 GitHub 上查看", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func toggleFavorite() {
        if let existing = favorites.first(where: { $0.repoId == item.id }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteItem(from: item))
        }
    }

    private func recordHistory() {
        let rid = item.id
        let descriptor = FetchDescriptor<HistoryItem>(
            predicate: #Predicate { $0.repoId == rid }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.viewedAt = Date()
            existing.titleZh = item.titleZh
            existing.summaryZh = item.summaryZh
            existing.avatarUrl = item.avatarUrl
        } else {
            modelContext.insert(HistoryItem(from: item))
        }
    }
}

struct IdentifiedURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

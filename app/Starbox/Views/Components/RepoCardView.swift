import SwiftUI

struct RepoCardView: View {
    let item: RepoItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.titleZh)
                        .font(.headline)
                        .foregroundStyle(StarboxTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Label(item.starsLabel, systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StarboxTheme.warm)
                        .labelStyle(.titleAndIcon)
                }
                Text(item.summaryZh)
                    .font(.subheadline)
                    .foregroundStyle(StarboxTheme.muted)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(item.heatPlainZh)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(StarboxTheme.softAmber)
                        .clipShape(Capsule())
                    if let scene = item.scene {
                        Text(scene)
                            .font(.caption)
                            .foregroundStyle(StarboxTheme.accent)
                    }
                }
            }
        }
        .padding(14)
        .background(StarboxTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    @ViewBuilder
    private var avatar: some View {
        Group {
            if let raw = item.avatarUrl, let url = URL(string: raw) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            StarboxTheme.softBlue
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(StarboxTheme.accent)
        }
    }
}

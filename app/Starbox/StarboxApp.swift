import SwiftUI
import SwiftData

@main
struct StarboxApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [FavoriteItem.self, HistoryItem.self])
    }
}

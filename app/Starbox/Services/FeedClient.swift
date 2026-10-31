import Foundation

struct FeedClient: Sendable {
    static let shared = FeedClient()

    /// Set in「我的 → 数据源地址」after GitHub Pages is live.
    /// Example: https://yourname.github.io/starbox/v1
    var baseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "feedBaseURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        // Default Pages URL — change after you push the repo under your account.
        return URL(string: "https://example.github.io/starbox/v1")!
    }

    func fetchAll() async throws -> FeedPayload {
        async let feed: FeedResponse = get("feed.json")
        async let categories: CategoriesResponse = get("categories.json")
        async let meta: MetaResponse = get("meta.json")
        return try await FeedPayload(feed: feed, categories: categories, meta: meta)
    }

    func loadBundled() -> FeedPayload? {
        guard
            let feedURL = Bundle.main.url(forResource: "feed", withExtension: "json"),
            let catURL = Bundle.main.url(forResource: "categories", withExtension: "json"),
            let metaURL = Bundle.main.url(forResource: "meta", withExtension: "json"),
            let feedData = try? Data(contentsOf: feedURL),
            let catData = try? Data(contentsOf: catURL),
            let metaData = try? Data(contentsOf: metaURL)
        else { return nil }

        let decoder = JSONDecoder()
        do {
            return FeedPayload(
                feed: try decoder.decode(FeedResponse.self, from: feedData),
                categories: try decoder.decode(CategoriesResponse.self, from: catData),
                meta: try decoder.decode(MetaResponse.self, from: metaData)
            )
        } catch {
            return nil
        }
    }

    private func get<T: Decodable>(_ file: String) async throws -> T {
        let url = baseURL.appendingPathComponent(file)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

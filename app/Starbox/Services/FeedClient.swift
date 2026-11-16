import Foundation

struct FeedClient: Sendable {
    static let shared = FeedClient()

    /// Override in「我的 → 数据源地址」; default points at the public Pages site.
    var baseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "feedBaseURL")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
           !override.isEmpty,
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://laolv421.github.io/StarBox/v1")!
    }

    func fetchAll() async throws -> FeedPayload {
        async let feed: FeedResponse = get("feed.json")
        async let categories: CategoriesResponse = get("categories.json")
        async let meta: MetaResponse = get("meta.json")
        let trends: TrendsResponse?
        do {
            trends = try await get("trends.json") as TrendsResponse
        } catch {
            trends = nil
        }
        return try await FeedPayload(
            feed: feed,
            categories: categories,
            meta: meta,
            trends: trends
        )
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
            var trends: TrendsResponse?
            if let trendsURL = Bundle.main.url(forResource: "trends", withExtension: "json"),
               let trendsData = try? Data(contentsOf: trendsURL) {
                trends = try? decoder.decode(TrendsResponse.self, from: trendsData)
            }
            return FeedPayload(
                feed: try decoder.decode(FeedResponse.self, from: feedData),
                categories: try decoder.decode(CategoriesResponse.self, from: catData),
                meta: try decoder.decode(MetaResponse.self, from: metaData),
                trends: trends
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

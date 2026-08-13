import SwiftUI

// MARK: - Search Suggestion Types

enum SearchSuggestion: Identifiable {
    case shop(ShopResult)
    case query(QueryResult)

    var id: String {
        switch self {
        case .shop(let s): return "shop-\(s.name)"
        case .query(let q): return "query-\(q.text)"
        }
    }

    struct ShopResult {
        let name: String
        let logoURL: URL?
        let rating: Double?
        let ratingCount: Int?
        let incentiveText: String?
    }

    struct QueryResult {
        let text: String
    }
}

// MARK: - Search Client

@Observable
@MainActor
final class ShopSearchClient {
    var results: [SearchSuggestion] = []
    var isLoading: Bool = false

    private var debounceTask: Task<Void, Never>?

    func search(query: String) {
        debounceTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true

        debounceTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            do {
                let fetched = try await fetchSuggestions(query: query)
                guard !Task.isCancelled else { return }
                results = fetched
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }
            isLoading = false
        }
    }

    func clear() {
        debounceTask?.cancel()
        results = []
        isLoading = false
    }

    // MARK: - API

    private func fetchSuggestions(query: String) async throws -> [SearchSuggestion] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://shop.app/web/api/search-suggestions?query=\(encoded)&first=10"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        if let authorization = await AgentStreamClient.resolveAuthorization() {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let nodes = json["nodes"] as? [[String: Any]] else { return [] }

        var suggestions: [SearchSuggestion] = []

        for node in nodes {
            let typeName = node["__typename"] as? String ?? ""

            if typeName == "SearchQueryPredictionShop" {
                guard let shop = node["shop"] as? [String: Any] else { continue }
                let name = shop["name"] as? String ?? ""
                let analytics = shop["productReviewAnalytics"] as? [String: Any]
                let rating = analytics?["averageRating"] as? Double
                let ratingCount = analytics?["totalProductRatings"] as? Int
                let theme = shop["visualTheme"] as? [String: Any]
                let logoImage = theme?["logoImage"] as? [String: Any]
                let logoURLString = logoImage?["url"] as? String
                let incentive = shop["shopCashIncentive"] as? [String: Any]
                var incentiveText: String? = nil
                if let incentive {
                    let displayType = incentive["adDisplayType"] as? String
                    if displayType == "AMOUNTS_VISIBLE",
                       let amount = incentive["totalCashDestinationAmount"] as? [String: Any],
                       let value = amount["amount"] as? String,
                       let num = Double(value) {
                        incentiveText = "Save $\(Int(num))"
                    } else {
                        incentiveText = "Offer available"
                    }
                }

                suggestions.append(.shop(.init(
                    name: name,
                    logoURL: logoURLString.flatMap { URL(string: $0) },
                    rating: rating,
                    ratingCount: ratingCount,
                    incentiveText: incentiveText
                )))
            } else if typeName == "SearchQueryPredictionBasic" {
                let text = node["query"] as? String ?? ""
                if !text.isEmpty {
                    suggestions.append(.query(.init(text: text)))
                }
            }
        }

        return suggestions
    }

}

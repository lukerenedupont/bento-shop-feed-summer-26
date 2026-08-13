import Foundation

/// Fetches the total product search result count from Shop's GraphQL API.
@Observable
@MainActor
final class SearchResultCount {
    var totalCount: Int = 0
    var isLoaded: Bool = false

    func fetch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        Task { @MainActor in
            do {
                let count = try await fetchCount(query: query)
                self.totalCount = count
                self.isLoaded = true
            } catch {
                print("[SearchCount] Error: \(error)")
            }
        }
    }

    private func fetchCount(query: String) async throws -> Int {
        guard let authorization = await AgentStreamClient.resolveAuthorization(),
              let url = URL(string: "https://server.shop.app/graphql") else {
            return 0
        }

        let graphqlQuery = """
        query WebModular($first: Int!, $query: String) {
          webProductSearchModular(first: $first, query: $query) {
            nodes {
              __typename
              ... on ProductSearchModuleResultCount {
                totalCount
              }
            }
          }
        }
        """

        let body: [String: Any] = [
            "query": graphqlQuery,
            "variables": ["first": 1, "query": query] as [String: Any]
        ]

        var request = AgentStreamClient.buildRequest(url: url, authorization: authorization)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            return 0
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let dataObj = json["data"] as? [String: Any],
              let searchModular = dataObj["webProductSearchModular"] as? [String: Any],
              let nodes = searchModular["nodes"] as? [[String: Any]] else {
            return 0
        }

        for node in nodes {
            if node["__typename"] as? String == "ProductSearchModuleResultCount",
               let count = node["totalCount"] as? Int {
                return count
            }
        }

        return 0
    }
}

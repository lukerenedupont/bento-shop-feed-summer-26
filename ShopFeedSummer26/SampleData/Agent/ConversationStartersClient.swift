import Foundation

/// Fetches personalized conversation starters from Shop Server on app load.
@Observable
@MainActor
final class ConversationStartersClient {
    static let shared = ConversationStartersClient()

    var starters: [String] = []
    var isLoaded: Bool = false

    private init() {
        Task { await fetch() }
    }

    func fetch() async {
        guard let authorization = await AgentStreamClient.resolveAuthorization() else {
            isLoaded = true
            return
        }

        let query = """
        {"query":"query { agentConversationStarters(numberOfStarters: 3, numberOfColumns: 1) { cardGrid { items { ... on AgentActionCard { label } } } } }"}
        """

        var request = URLRequest(url: URL(string: "https://server.shop.app/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.httpBody = query.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                isLoaded = true
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let startersObj = dataObj["agentConversationStarters"] as? [String: Any],
               let grid = startersObj["cardGrid"] as? [String: Any],
               let items = grid["items"] as? [[String: Any]] {
                starters = items.compactMap { $0["label"] as? String }
            }
        } catch {
            // Silent fail
        }

        isLoaded = true
    }

}

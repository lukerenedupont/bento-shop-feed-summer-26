import Foundation

/// A recent agent conversation.
struct RecentConversation: Identifiable, Codable {
    let id: String
    let title: String?
    let lastMessageSentAt: Date
    let thumbnailURLs: [URL]

    /// Relative date string for display
    var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: lastMessageSentAt, to: now)

        if let minutes = components.minute, minutes < 1 {
            return "Just now"
        } else if let minutes = components.minute, let hours = components.hour, hours == 0 {
            return "\(minutes) min ago"
        } else if let hours = components.hour, let days = components.day, days == 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return formatter.string(from: lastMessageSentAt)
        }
    }
}

/// Fetches conversation history from the Shop GraphQL API.
@Observable
@MainActor
final class ConversationHistoryClient {
    static let shared = ConversationHistoryClient()

    var conversations: [RecentConversation] = []
    var isLoading: Bool = false

    func fetch() async {
        guard let authorization = await AgentStreamClient.resolveAuthorization() else { return }
        isLoading = true

        do {
            let result = try await graphQL(
                authorization: authorization,
                query: "{ agentConversations(first: 20) { nodes { id lastMessageSentAt lastUpdatedAt title recentProductImages { url } } } }"
            )

            if let agentConversations = result["agentConversations"] as? [String: Any],
               let nodes = agentConversations["nodes"] as? [[String: Any]] {
                conversations = nodes.compactMap { parseConversation($0) }
            }
        } catch {
            print("[History] Error: \(error)")
        }

        isLoading = false
    }

    private func parseConversation(_ node: [String: Any]) -> RecentConversation? {
        guard let id = node["id"] as? String else { return nil }
        let title = node["title"] as? String

        let dateString = node["lastMessageSentAt"] as? String ?? node["lastUpdatedAt"] as? String ?? ""
        let date = ISO8601DateFormatter().date(from: dateString) ?? Date()

        var thumbnailURLs: [URL] = []
        if let images = node["recentProductImages"] as? [[String: Any]] {
            thumbnailURLs = images.compactMap { img in
                (img["url"] as? String).flatMap { URL(string: $0) }
            }
        }

        return RecentConversation(
            id: id,
            title: title,
            lastMessageSentAt: date,
            thumbnailURLs: thumbnailURLs
        )
    }

    private func graphQL(authorization: String, query: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://server.shop.app/graphql") else {
            throw URLError(.badURL)
        }

        let body: [String: Any] = ["query": query]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        return dataObj
    }

}

import Foundation

/// A product section from the agent's adaptive_ui response.
struct AgentProductSection: Identifiable {
    let id = UUID()
    let title: String?
    let subtitle: String?
    let products: [AgentProduct]
    let isComparison: Bool  // true when sourced from a Table element
    var isQuickSearch: Bool = false  // true when sourced from search:sdui_content event
    var isShelfSection: Bool = false  // true when parsed from a ShelfSection typename
}

/// A comparison attribute for a product (e.g. "Pros" → "Fast heating")
struct ComparisonAttribute: Identifiable {
    let id = UUID()
    let header: String
    let value: String
}

/// A product parsed from adaptive_ui ShelfSection/ListSection nodes.
struct AgentProduct: Identifiable, Hashable {
    static func == (lhs: AgentProduct, rhs: AgentProduct) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String
    let title: String
    let price: String
    let originalPrice: String?
    let imageURL: URL?
    let allImageURLs: [URL]
    let rating: Double?
    let ratingCount: Int?
    let shopName: String?
    let shopLogoURL: URL?
    let descriptors: [ComparisonAttribute]  // populated for comparison cards
    let labels: [String]  // e.g. "Best value", "Editor's pick"
}

// MARK: - Parsing

extension AgentProductSection {
    /// Parse a ShelfSection or ListSection JSON from adaptive_ui into a product section.
    static func parse(from json: [String: Any]) -> AgentProductSection? {
        let typeName = json["__typename"] as? String ?? ""
        guard typeName == "ShelfSection" || typeName == "ListSection" else { return nil }

        // Header
        let header = json["header"] as? [String: Any]
        let title = header?["title"] as? String
        let subtitleObj = header?["subtitle"] as? [String: Any]
        let subtitle = subtitleObj?["text"] as? String

        // Items
        let items = json["items"] as? [String: Any]
        let nodes = items?["nodes"] as? [[String: Any]] ?? []

        var products: [AgentProduct] = []
        for node in nodes {
            let cardType = node["__typename"] as? String ?? ""
            guard cardType == "ProductCard" || cardType == "ProductDetailsCard" else { continue }
            let isDetailsCard = cardType == "ProductDetailsCard"
            guard let productData = node["product"] as? [String: Any] else { continue }

            let id = productData["id"] as? String ?? UUID().uuidString
            let productTitle = productData["title"] as? String ?? ""

            // Price
            let priceObj = productData["price"] as? [String: Any]
            let priceAmount = priceObj?["amount"] as? String
            let price = priceAmount.flatMap { Double($0) }.map { Self.formatCurrency($0) } ?? ""

            let origObj = productData["originalPrice"] as? [String: Any]
            let origAmount = origObj?["amount"] as? String
            let originalPrice = origAmount.flatMap { Double($0) }.map { Self.formatCurrency($0) }

            // Images
            let images = productData["images"] as? [[String: Any]] ?? []
            let allImageURLs = images.compactMap { ($0["url"] as? String).flatMap { URL(string: $0) } }
            let imageURL = allImageURLs.first

            // Reviews
            let reviews = productData["reviewAnalytics"] as? [String: Any]
            let rating = reviews?["averageRating"] as? Double
            let ratingCount = reviews?["count"] as? Int

            // Shop
            let shop = productData["shop"] as? [String: Any]
            let shopName = shop?["name"] as? String
            let theme = shop?["visualTheme"] as? [String: Any]
            let logoImage = theme?["logoImage"] as? [String: Any]
            let logoURLString = logoImage?["url"] as? String
            let shopLogoURL = logoURLString.flatMap { URL(string: $0) }

            // Descriptors (comparison attributes from Table/ProductDetailsCard)
            var descriptors: [ComparisonAttribute] = []
            if isDetailsCard, let descriptorNodes = node["descriptors"] as? [[String: Any]] {
                for desc in descriptorNodes {
                    let text = Self.extractRichText(from: desc)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        // Try split on newline first: "**Header**\nValue"
                        let parts = text.split(separator: "\n", maxSplits: 1)
                        if parts.count == 2 {
                            let header = String(parts[0]).trimmingCharacters(in: .whitespaces)
                                .replacingOccurrences(of: "**", with: "")
                            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                            descriptors.append(ComparisonAttribute(header: header, value: value))
                        } else if text.contains(": ") {
                            // Fallback: "Header: Value" format
                            let colonParts = text.split(separator: ":", maxSplits: 1)
                            if colonParts.count == 2 {
                                let header = String(colonParts[0]).trimmingCharacters(in: .whitespaces)
                                    .replacingOccurrences(of: "**", with: "")
                                let value = String(colonParts[1]).trimmingCharacters(in: .whitespaces)
                                descriptors.append(ComparisonAttribute(header: header, value: value))
                            } else {
                                descriptors.append(ComparisonAttribute(header: "", value: text))
                            }
                        } else {
                            descriptors.append(ComparisonAttribute(header: "", value: text.replacingOccurrences(of: "**", with: "")))
                        }
                    }
                }
            }

            // Labels (overlay badges)
            var labels: [String] = []
            if let overlayItems = node["overlayItems"] as? [[String: Any]] {
                for item in overlayItems {
                    if item["kind"] as? String == "LABEL",
                       let label = item["label"] as? String {
                        labels.append(label)
                    }
                }
            }

            products.append(AgentProduct(
                id: id,
                title: productTitle,
                price: price,
                originalPrice: originalPrice,
                imageURL: imageURL,
                allImageURLs: allImageURLs,
                rating: rating,
                ratingCount: ratingCount,
                shopName: shopName,
                shopLogoURL: shopLogoURL,
                descriptors: descriptors,
                labels: labels
            ))
        }

        guard !products.isEmpty else { return nil }
        let hasDescriptors = products.contains { !$0.descriptors.isEmpty }
        var section = AgentProductSection(title: title, subtitle: subtitle, products: products, isComparison: hasDescriptors)
        section.isShelfSection = (typeName == "ShelfSection")
        return section
    }

    /// Extract plain text from a RichText JSON node (segments with text + optional bold traits)
    private static func extractRichText(from richText: [String: Any]) -> String {
        guard let segments = richText["segments"] as? [[String: Any]] else { return "" }
        var result = ""
        for segment in segments {
            guard let text = segment["text"] as? String else { continue }
            let traits = segment["traits"] as? [String] ?? []
            if traits.contains("BOLD") {
                result += "**\(text)**"
            } else {
                result += text
            }
        }
        return result
    }

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

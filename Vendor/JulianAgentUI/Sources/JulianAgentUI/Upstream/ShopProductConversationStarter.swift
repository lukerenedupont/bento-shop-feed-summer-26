import Foundation

/// Prepared display and submission text. Server starters are already localized; fixed native
/// order/fallback prompts resolve through the normal Shop translation bundle at creation.
struct ShopProductConversationStarter: Identifiable, Equatable, Sendable {
    let id: String
    let text: String

    init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    init(id localizationKey: String) {
        self.init(id: localizationKey, text: localizedString(localizationKey))
    }

    static func serverStarters(_ values: [String]) -> [Self] {
        var seen = Set<String>()
        return values.compactMap { value in
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, seen.insert(text).inserted else { return nil }
            return Self(id: text, text: text)
        }
    }
}

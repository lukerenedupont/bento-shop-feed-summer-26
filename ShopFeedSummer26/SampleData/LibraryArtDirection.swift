import Foundation
import SwiftUI

/// Deliberate, visually reviewed cover decisions for the native feed. This is
/// separate from catalog eligibility: having branding never approves a cover.
enum LibraryArtDirection {
    struct Cover: Decodable {
        let group: String
        let path: String
        let role: String
        let note: String
        let sha256: String
        let sourceProductID: String?
        let sourceMerchantID: String?
        let portraitOffsetRatio: Double?

        var url: URL? { ShopCanvasLibrary.resolve(path) }
    }

    static let covers: [Cover] = {
        do {
            return try JSONDecoder().decode([Cover].self, from: Data(contentsOf:
                ShopCanvasLibrary.rootURL.appendingPathComponent("editorial-covers.json")))
        } catch {
            assertionFailure("Missing reviewed library covers: \(error)")
            return []
        }
    }()

    private static let byGroup = Dictionary(uniqueKeysWithValues: covers.map { ($0.group, $0) })

    static func cover(forGroup group: String) -> Cover? {
        byGroup[group]
    }

    static func group(for story: FeedStory) -> String? {
        if story.id == "library-edit-all" { return "__all__" }
        return story.topicKeys.first { $0.hasPrefix("library-group:") }
            .map { String($0.dropFirst("library-group:".count)) }
    }

    static func cover(for story: FeedStory) -> Cover? {
        group(for: story).flatMap { byGroup[$0] }
    }

    static func railProducts(_ products: [ResolvedStoryProduct], for story: FeedStory) -> [ResolvedStoryProduct] {
        guard let heroID = cover(for: story)?.sourceProductID else { return products }
        // The hero already features this item. Keep the remaining rail in its
        // original relative order; the complete collection still includes it.
        return products.filter { $0.product.sourceProductID != heroID }
    }

    static func editorialDeck(for story: FeedStory) -> String? {
        guard let group = group(for: story) else { return nil }
        let decks = [
            "__all__": "A wide-angle view of the library, bringing every considered edit into one place.",
            "For the thoughtful host": "Warm, design-minded pieces for a table—and a home—that feels genuinely inviting.",
            "Gifts for him": "Useful objects, quiet luxuries, and unexpected details chosen to feel personal.",
            "Eckhaus Latta": "Texture, close-to-the-body layers, and off-kilter proportions in one expressive edit.",
            "Nordic Knots": "Graphic rugs and grounded neutrals that give a room shape without overwhelming it.",
            "objects": "Sculptural, useful, and slightly unexpected objects that reward a closer look.",
            "Travelling light": "Compact essentials and versatile layers for going farther with less in the bag.",
            "lighting": "Sculptural light and softer pools of glow for changing the mood of a room.",
            "fashion": "Distinctive silhouettes and thoughtful details for dressing beyond the obvious.",
            "For your self-care reset": "A movement study for training, recovery, and the quieter rituals in between.",
            "tableware": "Tactile pieces for everyday meals, long dinners, and a table with personality.",
            "Snow Peak": "Refined outdoor essentials that move comfortably between camp, travel, and home.",
            "Balenciaga": "Strong proportions, graphic accessories, and an intentionally amplified point of view.",
            "Soft launching fall": "Easy layers, softened color, and just enough structure for the season ahead.",
            "The best-dressed guest": "Polished pieces with enough personality to make an entrance without trying too hard.",
            "Jil Sander": "Clean lines, precise accessories, and a quieter approach to statement dressing.",
            "Dries Van Noten": "Rich color, expressive texture, and unexpected combinations built to be noticed slowly.",
            "Working from home": "Useful, good-looking pieces for making the everyday workspace feel more considered.",
            "books": "Beautiful volumes for reading, revisiting, and leaving open on the table.",
            "Big sports guy": "Performance-minded gear and everyday pieces for a life organized around movement.",
            "furniture": "Comfortable forms and characterful pieces that help a room feel lived in.",
            "On": "Technical footwear and streamlined layers selected for movement in and beyond the city.",
            "Lemaire": "Soft tailoring, useful accessories, and understated shapes with an easy sense of proportion.",
            "All suited up": "Relaxed tailoring and sharp finishing pieces for structure without the stiffness.",
            "home textiles": "Tactile layers that bring softness, warmth, and a little more depth to a room.",
            "The coziest corner": "Low light, generous texture, and comforting pieces for the best seat in the house.",
            "JW Anderson": "Playful accessories and sculptural details that make the familiar feel less expected.",
            "Our Legacy": "Washed texture, relaxed layers, and everyday pieces with a subtly unconventional edge.",
            "Turn off the big light": "Lamps and ambient glow for rooms that feel better after sunset.",
            "accessories": "Small finishing pieces with enough character to shift the whole look.",
        ]
        return decks[group]
    }

    static func title(for group: String) -> String {
        let titles = [
            "objects": "Objects with character", "lighting": "Light, considered",
            "fashion": "A different point of view", "tableware": "Set the table",
            "books": "A well-read home", "furniture": "Room to live",
            "home textiles": "A softer landing", "accessories": "The finishing touches",
        ]
        return titles[group] ?? group
    }
}

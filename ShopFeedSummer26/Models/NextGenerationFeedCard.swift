import Foundation

/// PROTOTYPE — a finite grammar for evaluating whether generative feed cards
/// can feel highly varied while remaining legible, shoppable, and Shop-native.
/// The grammar is intentionally data-only: rendering and interaction live in
/// `NextGenerationFeedCardView`, while catalog truth stays in SampleMerchant.
enum NextGenerationCardLayout: String, CaseIterable, Identifiable {
    case focusFrame
    case orbit
    case splitDecision
    case swipeStack
    case mosaicSpotlight
    case merchantWindow
    case colorWash
    case productTimeline
    case comparisonScrub
    case kitBuilder
    case constellation
    case catalogTicker
    case detailLens
    case priceLadder
    case dropReveal
    case editorialFold
    case bundleBuilder
    case textureRail
    case productStage
    case rapidPoll

    var id: String { rawValue }
}

struct NextGenerationFeedCardSpec: Identifiable {
    let id: String
    let layout: NextGenerationCardLayout
    let eyebrow: String
    let title: String
    let subtitle: String
    let accentHex: String
    let productReferences: [FeedStory.ProductReference]

    var prefersDarkNavigationText: Bool {
        [.colorWash, .comparisonScrub, .priceLadder].contains(layout)
    }

    func resolvedProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        productReferences.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return nil
            }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }
}

@MainActor
enum NextGenerationFeedCardCatalog {
    static let prototypeEnabled = true

    private static let palette = [
        "#263B35", "#6E5AE6", "#E8653D", "#3D6C8A", "#EEE8DB",
        "#171717", "#C7E66A", "#8A4D68", "#F1B84B", "#47605C",
        "#3159A5", "#A8C8BD", "#E8D7CE", "#5A4637", "#D75555",
        "#6D78A8", "#C4A46A", "#2F7772", "#E8A6B8", "#45434F",
    ]

    static func cards(
        topic: BuyerFeedTopic,
        sourceStories: [FeedStory],
        merchants: [SampleMerchant]
    ) -> [NextGenerationFeedCardSpec] {
        guard prototypeEnabled else { return [] }

        let prioritizedMerchantIDs = sourceStories.flatMap { story in
            story.productReferencesMerchantIDs
        }
        var seenMerchantIDs = Set<String>()
        let orderedMerchants = (
            prioritizedMerchantIDs.compactMap { id in merchants.first { $0.id == id } }
            + merchants
        ).filter { merchant in
            !merchant.products.isEmpty && seenMerchantIDs.insert(merchant.id).inserted
        }
        guard !orderedMerchants.isEmpty else { return [] }

        return NextGenerationCardLayout.allCases.enumerated().map { index, layout in
            let merchant = orderedMerchants[index % orderedMerchants.count]
            let secondary = orderedMerchants[(index + 5) % orderedMerchants.count]
            let tertiary = orderedMerchants[(index + 11) % orderedMerchants.count]
            let products = products(
                for: layout,
                primary: merchant,
                secondary: secondary,
                tertiary: tertiary,
                offset: index
            )
            let lead = products[0]
            let copy = copy(
                for: layout,
                topic: topic,
                merchant: merchant,
                leadProduct: lead.product
            )

            return NextGenerationFeedCardSpec(
                id: "next-gen-\(topic.id)-\(layout.rawValue)",
                layout: layout,
                eyebrow: copy.eyebrow,
                title: copy.title,
                subtitle: copy.subtitle,
                accentHex: palette[index % palette.count],
                productReferences: products.prefix(8).map {
                    FeedStory.ProductReference(
                        merchantID: $0.merchant.id,
                        productID: $0.product.id
                    )
                }
            )
        }
    }

    private static func products(
        for layout: NextGenerationCardLayout,
        primary: SampleMerchant,
        secondary: SampleMerchant,
        tertiary: SampleMerchant,
        offset: Int
    ) -> [ResolvedStoryProduct] {
        let isMultiMerchant = [
            NextGenerationCardLayout.orbit,
            .splitDecision,
            .mosaicSpotlight,
            .constellation,
            .rapidPoll,
        ].contains(layout)
        let sources = isMultiMerchant ? [primary, secondary, tertiary] : [primary]

        var result: [ResolvedStoryProduct] = []
        var seen = Set<String>()
        for pass in 0..<8 {
            let merchant = sources[pass % sources.count]
            let product = merchant.products[(pass + offset) % merchant.products.count]
            let resolved = ResolvedStoryProduct(merchant: merchant, product: product)
            if seen.insert(resolved.id).inserted {
                result.append(resolved)
            }
        }
        if result.isEmpty {
            result.append(ResolvedStoryProduct(merchant: primary, product: primary.products[0]))
        }
        return result
    }

    private static func copy(
        for layout: NextGenerationCardLayout,
        topic: BuyerFeedTopic,
        merchant: SampleMerchant,
        leadProduct: SampleMerchant.Product
    ) -> (eyebrow: String, title: String, subtitle: String) {
        let merchantName = merchant.displayName
        let productKind = leadProduct.productType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = productKind?.isEmpty == false ? productKind! : "finds"

        return switch layout {
        case .focusFrame:
            (merchantName, leadProduct.title, "Tap through the details")
        case .orbit:
            ("In your orbit", "Connected finds", "Drag to explore the assortment")
        case .splitDecision:
            ("A quick decision", "Which direction?", "Two real picks from \(merchantName)")
        case .swipeStack:
            ("Keep or skip", "A stack from \(merchantName)", "Swipe the lead card to keep moving")
        case .mosaicSpotlight:
            ("Shop the mosaic", "The \(kind) edit", "Tap any tile to bring it forward")
        case .merchantWindow:
            ("Merchant window", merchantName, merchant.description)
        case .colorWash:
            ("Color story", leadProduct.title, "Shift the mood, keep the product")
        case .productTimeline:
            (topic.label, "A path through \(merchantName)", "Move through the edit one step at a time")
        case .comparisonScrub:
            ("Side by side", "Compare the details", "Drag across two products")
        case .kitBuilder:
            ("Build your kit", merchantName, "Tap products to add or remove them")
        case .constellation:
            ("Connected finds", "A \(topic.label.lowercased()) constellation", "Tap a node to focus")
        case .catalogTicker:
            ("Live catalog", merchantName, "A fast-moving strip of real inventory")
        case .detailLens:
            ("Look closer", leadProduct.title, "Drag the lens across the product")
        case .priceLadder:
            ("Shop by price", "A range from \(merchantName)", "Tap a rung to inspect it")
        case .dropReveal:
            ("One-product drop", merchantName, "Press to reveal today’s pick")
        case .editorialFold:
            ("Shop editorial", leadProduct.title, "Open the fold for the full story")
        case .bundleBuilder:
            ("Make it yours", "Build a \(merchantName) bundle", "Select the combination that fits")
        case .textureRail:
            ("Material study", "Details from \(merchantName)", "Swipe through close product crops")
        case .productStage:
            ("On the stage", leadProduct.title, "Drag to turn the presentation")
        case .rapidPoll:
            ("Tune your feed", "More like this?", "Your answer reshapes the next recommendation")
        }
    }
}

private extension FeedStory {
    var productReferencesMerchantIDs: [String] {
        products.map(\.merchantID)
    }
}

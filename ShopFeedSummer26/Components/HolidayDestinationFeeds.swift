import SwiftUI

/// Native adaptations of the Holiday 2026 playground destinations. The shared
/// Home header remains outside these views; these own the progressive content
/// below it and use this prototype's real personalized assortment.
struct HolidaySaleDestinationFeed: View {
    let products: [ResolvedStoryProduct]
    let topInset: CGFloat
    var onFilterPinned: (Bool) -> Void

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var marketplaceRotation: Double = 0
    @State private var filtersArePinned = false

    private var flashDeals: [ResolvedStoryProduct] { slice(0, count: 6) }
    private var dealsForYou: [ResolvedStoryProduct] { slice(6, count: 6) }
    private var allDeals: [ResolvedStoryProduct] {
        products.isEmpty ? [] : Array((products + products).prefix(12))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: GravitySpacing.space24) {
                saleLeadIn
                HolidayFilterRail(labels: ["Women", "Beauty", "Men", "Food & drink"])
                    .opacity(filtersArePinned ? 0 : 1)
                    .onGeometryChange(for: Bool.self) { proxy in
                        let stickyTop = max(
                            topInset
                                - FeedNavigationStyle.controlSize
                                - GravitySpacing.space8,
                            0
                        )
                        return proxy.frame(in: .global).minY <= stickyTop
                    } action: { _, isPinned in
                        guard filtersArePinned != isPinned else { return }
                        filtersArePinned = isPinned
                        onFilterPinned(isPinned)
                    }

                HolidayProductRail(
                    title: "Today’s flash deals",
                    subtitle: AnyView(HolidayCountdown()),
                    products: flashDeals,
                    onSelect: open
                )

                HolidayProductRail(
                    title: "Deals for you",
                    products: dealsForYou,
                    onSelect: open
                )

                if let merchant = products.first?.merchant {
                    HolidayEditorialCard(
                        merchant: merchant,
                        title: "The holiday edit",
                        subtitle: "Gifts worth giving"
                    )
                    .padding(.horizontal, GravitySpacing.space16)
                }

                brandRails

                HolidayProductGrid(
                    title: "Shop all deals",
                    products: allDeals,
                    onSelect: open
                )
            }
            .padding(.bottom, FeedCardStyle.bottomNavigationClearance + 40)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .onDisappear { onFilterPinned(false) }
    }

    private var saleLeadIn: some View {
        VStack(spacing: -65) {
            saleHeader
            shopCashUtilityCard
                .zIndex(1)
        }
        .containerRelativeFrame(.horizontal)
        .padding(.bottom, GravitySpacing.space4)
    }

    private var saleHeader: some View {
        Image("holiday-feed-banner")
            .resizable()
            .scaledToFill()
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.34), location: 0),
                        .init(color: .clear, location: 0.42),
                        .init(color: .black.opacity(0.34), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                VStack(spacing: GravitySpacing.space12) {
                    Text("Gift more,\nGet more")
                        .holidayCampaignTitleStyle()

                    Text("Earn more on your holiday\nhauls. This week only.")
                        .holidayCampaignSupportingTextStyle()
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .gravityShadow(GravityShadows.feedText)
                .padding(.top, topInset + 76)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.64), location: 0.72),
                        .init(color: .white, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 144)
                .allowsHitTesting(false)
            }
        .containerRelativeFrame(.horizontal)
        .frame(height: topInset + 360)
        .clipped()
    }

    private var shopCashUtilityCard: some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            HStack(spacing: GravitySpacing.space12) {
                holidayMarketplaceBadge

                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text("Get up to $100 Shop Cash")
                        .gravityTextStyle(GravityTypography.bodyTitleLarge)
                        .foregroundStyle(GravityColors.text)
                        .lineLimit(1)
                    Text("Expires Nov 8 · Tap to learn how")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(GravityColors.textSecondary)
                }

                Spacer(minLength: GravitySpacing.space4)

                Image("holiday-offer-chevron")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 6, height: 10)
                    .foregroundStyle(GravityColors.text)
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
            }
            .padding(.horizontal, GravitySpacing.space16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 92)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, GravitySpacing.space12)
        .frame(maxWidth: .infinity)
    }

    /// The campaign seal turns slowly enough to feel ambient rather than like
    /// a loading indicator. Reduce Motion leaves it in its resting position.
    private var holidayMarketplaceBadge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x5433EB))

            Image("holiday-marketplace-wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 65, height: 65)
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .rotationEffect(.degrees(marketplaceRotation))
        .onAppear {
            guard !reduceMotion, marketplaceRotation == 0 else { return }
            withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                marketplaceRotation = 360
            }
        }
    }

    private var brandRails: some View {
        let groups = Dictionary(grouping: products, by: { $0.merchant.id })
        let merchants = products.reduce(into: [SampleMerchant]()) { result, item in
            if !result.contains(where: { $0.id == item.merchant.id }) {
                result.append(item.merchant)
            }
        }

        return VStack(alignment: .leading, spacing: GravitySpacing.space24) {
            Text("Brands for you")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, GravitySpacing.space16)

            ForEach(Array(merchants.prefix(3))) { merchant in
                VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                    HStack(spacing: GravitySpacing.space10) {
                        MerchantAvatarView(merchant: merchant, size: 40)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(merchant.displayName)
                                .gravityTextStyle(GravityTypography.bodyTitleSmall)
                            Text("Holiday picks from \(merchant.displayName)")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(Color(hex: 0x6C4DFF))
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space16)

                    HolidayProductRail(
                        title: nil,
                        products: groups[merchant.id] ?? [],
                        onSelect: open
                    )
                }
            }
        }
    }

    private func slice(_ start: Int, count: Int) -> [ResolvedStoryProduct] {
        guard !products.isEmpty else { return [] }
        let repeated = products + products
        return Array(repeated.dropFirst(min(start, repeated.count)).prefix(count))
    }

    private func open(_ item: ResolvedStoryProduct) {
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

struct HolidayGiftGuidesDestinationFeed: View {
    let products: [ResolvedStoryProduct]
    let topInset: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator

    private let guides = [
        ("Slow Mornings", "Curated by Jesse Jenkins"),
        ("Hosting Era", "Perfect gifts for dinner party enthusiasts"),
        ("Weekend Adventures", "For the ones who leave on Friday night"),
        ("Sweat & Reset", "Curated by Camille Okafor"),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: GravitySpacing.space32) {
                ForEach(Array(guides.enumerated()), id: \.offset) { index, guide in
                    HolidayGiftGuide(
                        title: guide.0,
                        attribution: guide.1,
                        hero: guideProducts(for: index).first,
                        onSelect: open
                    )

                    HolidayProductRail(
                        title: railTitle(at: index),
                        products: Array(guideProducts(for: index).dropFirst().prefix(5)),
                        onSelect: open
                    )

                    if index == 1 {
                        HolidayGiftAgent(products: Array(guideProducts(for: index).dropFirst().prefix(4)))
                    }
                }
            }
            .padding(.top, topInset + GravitySpacing.space20)
            .padding(.bottom, FeedCardStyle.bottomNavigationClearance + 40)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    private func railTitle(at index: Int) -> String {
        ["Gifts under $100", "Must-have gifts under $50", "Trending gifts", "Cozy gifts"][index]
    }

    /// Keep the editorial stories anchored in the buyer's real assortment,
    /// while avoiding arbitrary first-shelf products and false price claims.
    private func guideProducts(for index: Int) -> [ResolvedStoryProduct] {
        let keywords = [
            ["coffee", "tea", "mug", "kettle", "breakfast", "bathrobe", "sleepwear", "slipper", "candle", "bedding"],
            ["table", "dinner", "serve", "serving", "bowl", "plate", "glass", "linen", "wine", "kitchen"],
            ["travel", "weekend", "outdoor", "camp", "hike", "bag", "backpack", "bottle", "boot", "jacket"],
            ["training", "workout", "running", "yoga", "recovery", "gym", "wellness", "sweat", "towel", "cozy", "blanket", "throw", "pillow", "knit"],
        ][index]
        let priceLimit: Double? = index == 0 ? 100 : (index == 1 ? 50 : nil)
        let eligible = products.filter { item in
            guard let priceLimit else { return true }
            return numericPrice(item) <= priceLimit
        }
        let scored = eligible.enumerated().map { offset, item in
            let text = ([item.product.title, item.product.productType ?? "", item.product.vendor]
                + item.product.tags)
                .joined(separator: " ")
                .lowercased()
            let score = keywords.reduce(0) { result, keyword in
                result + (text.contains(keyword) ? 1 : 0)
            }
            return (offset: offset, score: score, item: item)
        }
        return scored.sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.offset < rhs.offset : lhs.score > rhs.score
        }
        .map(\.item)
    }

    private func numericPrice(_ item: ResolvedStoryProduct) -> Double {
        Double(item.product.price.replacingOccurrences(of: ",", with: "")) ?? .greatestFiniteMagnitude
    }

    private func open(_ item: ResolvedStoryProduct) {
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

struct HolidayFilterRail: View {
    let labels: [String]
    var showsStickyBackdrop = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space6) {
                Button { HapticFeedback.light.fire() } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 38, height: 38)
                        .background(.white, in: Circle())
                        .gravityShadow(GravityShadows.small)
                }
                ForEach(labels, id: \.self) { label in
                    Button { HapticFeedback.light.fire() } label: {
                        Text(label)
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, GravitySpacing.space16)
                            .frame(height: 38)
                            .background(.white, in: Capsule())
                            .gravityShadow(GravityShadows.small)
                    }
                }
            }
            .foregroundStyle(GravityColors.text)
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.vertical, GravitySpacing.space4)
        }
        .scrollClipDisabled()
        .background(alignment: .top) {
            if showsStickyBackdrop {
                StickyFilterBackdrop()
            }
        }
    }
}

/// Shared protection for filter rails that replace the top-level topic bar.
/// The material remains strongest through the controls, then dissolves into
/// the scrolling page instead of reading as a separate navigation surface.
struct StickyFilterBackdrop: View {
    var height: CGFloat = 136
    var opaqueStop: CGFloat = 0.54

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(
                colors: [.white.opacity(0.94), .white.opacity(0.76), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.92), location: opaqueStop),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: height)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

private struct HolidayCountdown: View {
    private static let deadline = Date().addingTimeInterval(10 * 3600 + 15 * 60 + 3)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(max(0, Self.deadline.timeIntervalSince(context.date)))
            HStack(spacing: 3) {
                unit(remaining / 3600, "h")
                unit(remaining % 3600 / 60, "m")
                unit(remaining % 60, "s")
                Text("left")
                    .foregroundStyle(GravityColors.textSecondary)
            }
            .font(.system(size: 12, weight: .semibold))
        }
    }

    private func unit(_ value: Int, _ suffix: String) -> some View {
        Text(String(format: "%02d%@", value, suffix))
            .monospacedDigit()
            .foregroundStyle(Color(hex: 0xEA3323))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: 0xFFE8E5), in: Capsule())
    }
}

private struct HolidayProductRail: View {
    var title: String?
    var subtitle: AnyView? = nil
    let products: [ResolvedStoryProduct]
    let onSelect: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            if let title {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                    subtitle
                }
                .padding(.horizontal, GravitySpacing.space16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space10) {
                    ForEach(products) { item in
                        Button {
                            HapticFeedback.light.fire()
                            onSelect(item)
                        } label: {
                            HolidayProductTile(item: item)
                                .frame(width: 168)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }
}

private struct HolidayProductTile: View {
    let item: ResolvedStoryProduct

    var body: some View {
        ProductCard(
            image: nil,
            imageURL: item.product.imageURL,
            merchantName: item.merchant.displayName,
            productName: item.product.title,
            rating: item.merchant.rating,
            ratingCount: item.merchant.totalRatings,
            price: formatPrice(item.product.price)
        )
    }
}

private struct HolidayProductGrid: View {
    let title: String
    let products: [ResolvedStoryProduct]
    let onSelect: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: GravitySpacing.space16
            ) {
                ForEach(products) { item in
                    Button { onSelect(item) } label: {
                        HolidayProductTile(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, GravitySpacing.space16)
    }
}

private struct HolidayEditorialCard: View {
    let merchant: SampleMerchant
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MerchantCoverImage(merchant: merchant)
                .frame(height: 210)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.56)], startPoint: .top, endPoint: .bottom)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 20, weight: .semibold))
                    Text(subtitle).font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.white)
            .padding(GravitySpacing.space16)
        }
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
    }
}

private struct HolidayGiftGuide: View {
    let title: String
    let attribution: String
    let hero: ResolvedStoryProduct?
    let onSelect: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(spacing: GravitySpacing.space20) {
            VStack(spacing: GravitySpacing.space12) {
                Text(title)
                    .holidayCampaignTitleStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(attribution)
                    .holidayCampaignSupportingTextStyle()
                    .multilineTextAlignment(.center)
                HolidayPrimaryCTA(title: "Start shopping") {
                    if let hero { onSelect(hero) }
                }
            }

            if let hero {
                Button { onSelect(hero) } label: {
                    MerchantCoverImage(merchant: hero.merchant)
                        .frame(height: 300)
                        .clipped()
                        .overlay {
                            LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, GravitySpacing.space48)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HolidayGiftAgent: View {
    let products: [ResolvedStoryProduct]

    private let prompts = [
        "Help me find the perfect gift for…",
        "Something for my partner who has everything",
        "Thoughtful gifts under $50",
        "Gifts that arrive before the 24th",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            Text("Find the perfect gift")
                .font(.system(size: 20, weight: .semibold))
                .padding(.horizontal, GravitySpacing.space16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space10) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                                .fill(Color(hex: 0xF0F0F0))
                            Text("“\(prompt)”")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(GravitySpacing.space12)
                            if products.indices.contains(index) {
                                ProductImageView(
                                    product: products[index].product,
                                    merchant: products[index].merchant,
                                    fallbackIndex: index
                                )
                                .frame(width: 90, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            Image(systemName: "arrow.up.right")
                                .frame(width: 36, height: 36)
                                .background(.white, in: Circle())
                                .padding(GravitySpacing.space8)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        }
                        .frame(width: 177, height: 221)
                    }
                }
                .padding(.horizontal, GravitySpacing.space16)
            }
        }
    }
}

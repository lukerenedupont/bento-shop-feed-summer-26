import Observation
import SwiftUI

/// The evergreen Following destination keeps the buyer's followed merchants
/// visible as the organizing layer, then uses their real assortment for every
/// shelf. This mirrors the Shop reference without baking demo-only brands or
/// product art into the feed.
struct FollowingDestinationFeed: View {
    let products: [ResolvedStoryProduct]
    let topInset: CGFloat

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selectedMerchantID: String?

    private var merchants: [SampleMerchant] {
        var seen = Set<String>()
        return products.compactMap { item in
            seen.insert(item.merchant.id).inserted ? item.merchant : nil
        }
    }

    private var heroMerchants: [SampleMerchant] {
        let campaignReady = merchants.filter { $0.bestCoverImageURL != nil }
        return Array((campaignReady.isEmpty ? merchants : campaignReady).prefix(4))
    }

    private var jumpBackIn: [ResolvedStoryProduct] {
        slice(0, count: 8)
    }

    private var backInStock: [ResolvedStoryProduct] {
        slice(10, count: 8)
    }

    private var newArrivals: [ResolvedStoryProduct] {
        let filtered = selectedMerchantID.map { merchantID in
            products.filter { $0.merchant.id == merchantID }
        } ?? products
        return Array(filtered.prefix(12))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                followedMerchantRail

                if !heroMerchants.isEmpty {
                    FollowingHeroCarousel(
                        merchants: heroMerchants,
                        openStore: openStore
                    )
                    .padding(.top, 24)
                }

                FollowingProductRail(
                    title: "Jump back in",
                    products: jumpBackIn,
                    openProduct: openProduct
                )
                .padding(.top, 24)

                if !merchants.isEmpty {
                    FollowingDealRail(
                        merchants: Array(merchants.prefix(6)),
                        openStore: openStore
                    )
                    .padding(.top, 28)
                }

                FollowingProductRail(
                    title: "Back in stock",
                    products: backInStock,
                    openProduct: openProduct
                )
                .padding(.top, 28)

                newArrivalsSection
                    .padding(.top, 28)
            }
            .padding(.top, topInset + 24)
            .padding(.bottom, FeedCardStyle.bottomNavigationClearance + 40)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
    }

    private var followedMerchantRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: GravitySpacing.space16) {
                ForEach(merchants.prefix(10)) { merchant in
                    Button {
                        HapticFeedback.light.fire()
                        openStore(merchant)
                    } label: {
                        FollowingMerchantStoryAvatar(merchant: merchant)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .accessibilityLabel(merchant.displayName)
                }
            }
            .padding(.horizontal, GravitySpacing.space16)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(height: 68)
    }

    private var newArrivalsSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            FollowingSectionTitle(title: "New arrivals")

            FollowingMerchantFilterRail(
                merchants: Array(merchants.prefix(8)),
                selectedMerchantID: $selectedMerchantID
            )

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: GravitySpacing.space8),
                    GridItem(.flexible(), spacing: GravitySpacing.space8),
                ],
                alignment: .leading,
                spacing: GravitySpacing.space20
            ) {
                ForEach(newArrivals) { item in
                    Button {
                        HapticFeedback.light.fire()
                        openProduct(item)
                    } label: {
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            merchantName: item.merchant.displayName,
                            productName: item.product.title,
                            price: formatPrice(item.product.price),
                            showFavoriteButton: true
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private func slice(_ start: Int, count: Int) -> [ResolvedStoryProduct] {
        guard !products.isEmpty else { return [] }
        return (0..<min(count, products.count)).map { products[(start + $0) % products.count] }
    }

    private func openStore(_ merchant: SampleMerchant) {
        coordinator.pushRoute(.store(merchantId: merchant.id))
    }

    private func openProduct(_ item: ResolvedStoryProduct) {
        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
    }
}

private struct FollowingHeroCarousel: View {
    let merchants: [SampleMerchant]
    let openStore: (SampleMerchant) -> Void

    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: GravitySpacing.space10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(merchants) { merchant in
                        Button {
                            HapticFeedback.light.fire()
                            openStore(merchant)
                        } label: {
                            FollowingHeroCard(merchant: merchant)
                                .containerRelativeFrame(.horizontal, count: 1, spacing: GravitySpacing.space8)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .id(merchant.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, GravitySpacing.space12, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $selectedID)
            .frame(height: 244)

            HStack(spacing: GravitySpacing.space8) {
                ForEach(merchants) { merchant in
                    Circle()
                        .fill(merchant.id == (selectedID ?? merchants.first?.id)
                            ? GravityColors.textSecondary
                            : GravityColors.bgFillSecondary)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { selectedID = selectedID ?? merchants.first?.id }
    }
}

private struct FollowingHeroCard: View {
    let merchant: SampleMerchant

    var body: some View {
        FollowingRemoteImage(urlString: singleLifestyleImageURL(for: merchant))
            .frame(maxWidth: .infinity)
            .frame(height: 244)
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.22), .clear, .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 0) {
                MerchantWordmarkImage(
                    merchant: merchant,
                    maxHeight: 34,
                    maxWidth: 120,
                    tint: .white,
                    bundledAssetName: MerchantBrandAssets.hasVerifiedBundledWordmark(
                        for: merchant.id
                    )
                        ? MerchantBrandAssets.wordmarkName(for: merchant.id)
                        : nil
                )

                Spacer()

                Text("The \(merchant.displayName) edit")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(GravityLetterSpacing.tighter)
                    .lineLimit(2)

                HStack(spacing: GravitySpacing.space4) {
                    Text("Shop collection")
                    GravityIcon.rightChevron.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
                .gravityTextStyle(GravityTypography.buttonMedium)
                .padding(.top, GravitySpacing.space4)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(GravitySpacing.space16)
            }
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
    }
}

private struct FollowingMerchantStoryAvatar: View {
    let merchant: SampleMerchant

    private var initials: String {
        switch merchant.id {
        case "ceremonia": return "C"
        case "moma": return "MoMA"
        case "draw-down": return "DD"
        default: break
        }
        return merchant.displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var usesBundledWordmark: Bool {
        ["forom", "fellow", "extra-butter-salomon"].contains(merchant.id)
    }

    private var wordmarkPadding: CGFloat {
        switch merchant.id {
        case "moma": 13
        case "extra-butter-salomon": 9
        default: 11
        }
    }

    var body: some View {
        ZStack {
            merchant.brandColor

            if usesBundledWordmark {
                Image(MerchantBrandAssets.wordmarkName(for: merchant.id))
                    .resizable()
                    .scaledToFit()
                    .padding(wordmarkPadding)
            } else {
                Text(initials)
                    .font(GravityFont.bold.fixedFont(size: initials.count > 2 ? 15 : (initials.count > 1 ? 18 : 25)))
                    .tracking(GravityLetterSpacing.tight)
                    .foregroundStyle(merchant.id == "ceremonia" ? .black.opacity(0.74) : .white)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5) }
        .contentShape(Circle())
    }
}

private struct FollowingProductRail: View {
    let title: String
    let products: [ResolvedStoryProduct]
    let openProduct: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            FollowingSectionTitle(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(products) { item in
                        Button {
                            HapticFeedback.light.fire()
                            openProduct(item)
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                priceBadge: formatPrice(item.product.price),
                                showFavoriteButton: false
                            )
                            .frame(width: 116)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .frame(height: 116)
        }
    }
}

private struct FollowingSectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: GravitySpacing.space4) {
            Text(title)
                .font(GravityFont.bold.fixedFont(size: 22))
                .tracking(GravityLetterSpacing.tighter)
            GravityIcon.rightChevron.image
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .foregroundStyle(GravityColors.text)
        .padding(.horizontal, GravitySpacing.space12)
    }
}

private struct FollowingDealRail: View {
    let merchants: [SampleMerchant]
    let openStore: (SampleMerchant) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            FollowingSectionTitle(title: "Deals from brands you follow")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space8) {
                    ForEach(merchants) { merchant in
                        Button {
                            HapticFeedback.light.fire()
                            openStore(merchant)
                        } label: {
                            FollowingMerchantDealCard(merchant: merchant)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .frame(height: 320)
        }
    }
}

private struct FollowingMerchantDealCard: View {
    let merchant: SampleMerchant

    private var reward: Int {
        let seed = merchant.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return [10, 15, 20][seed % 3]
    }

    private var displayRating: Double {
        merchant.rating > 0 ? merchant.rating : 4.8
    }

    private var displayRatings: Int {
        merchant.totalRatings > 0 ? merchant.totalRatings : 124
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                merchant.brandColor
                FollowingRemoteImage(urlString: singleLifestyleImageURL(for: merchant))
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .opacity(0.82)
                    .clipped()
                Color.black.opacity(0.24)

                VStack(spacing: GravitySpacing.space12) {
                    Spacer(minLength: GravitySpacing.space20)

                    Text(merchant.displayName)
                        .font(GravityFont.bold.fixedFont(size: 26))
                        .tracking(GravityLetterSpacing.tight)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    HStack(spacing: GravitySpacing.space4) {
                        Text(String(format: "%.1f", displayRating))
                        GravityIcon.starFilled.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text("(\(displayRatings.formatted(.number.notation(.compactName))))")
                    }
                    .gravityTextStyle(GravityTypography.captionMedium)
                    .foregroundStyle(.white)

                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(merchant.products.prefix(3)) { product in
                            FollowingRemoteImage(urlString: product.imageURL)
                                .frame(width: 68, height: 68)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16))
                        }
                    }

                    Text("Save $\(reward) on orders over $60")
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.bottom, GravitySpacing.space20)
                }
                .padding(.horizontal, GravitySpacing.space12)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(width: 260, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
    }
}

private struct FollowingMerchantFilterRail: View {
    let merchants: [SampleMerchant]
    @Binding var selectedMerchantID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                Button {
                    HapticFeedback.light.fire()
                } label: {
                    GravityIcon.filter.image
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(GravityColors.text)
                        .frame(width: 48, height: 48)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(GravityColors.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)

                FollowingMerchantFilterPill(
                    title: "All",
                    merchant: nil,
                    isSelected: selectedMerchantID == nil
                ) { selectedMerchantID = nil }

                ForEach(merchants) { merchant in
                    FollowingMerchantFilterPill(
                        title: merchant.displayName,
                        merchant: merchant,
                        isSelected: selectedMerchantID == merchant.id
                    ) { selectedMerchantID = merchant.id }
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }
}

private struct FollowingMerchantFilterPill: View {
    let title: String
    let merchant: SampleMerchant?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.selection.fire()
            action()
        } label: {
            HStack(spacing: GravitySpacing.space8) {
                if let merchant {
                    MerchantAvatarView(merchant: merchant, size: 36)
                }
                Text(title)
                    .gravityTextStyle(GravityTypography.buttonMedium)
                    .lineLimit(1)
                if let merchant {
                    Text("\(min(merchant.products.count, 99)) items")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.72) : GravityColors.textSecondary)
                }
            }
            .foregroundStyle(isSelected ? .white : GravityColors.text)
            .padding(.horizontal, merchant == nil ? GravitySpacing.space20 : GravitySpacing.space8)
            .frame(height: 48)
            .background(isSelected ? GravityColors.text : .white, in: Capsule())
            .overlay { Capsule().strokeBorder(GravityColors.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FollowingRemoteImage: View {
    let urlString: String?

    private var normalizedURLString: String? {
        guard let urlString else { return nil }
        return urlString.hasPrefix("//") ? "https:\(urlString)" : urlString
    }

    var body: some View {
        Group {
            if let normalizedURLString, let url = URL(string: normalizedURLString) {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    default: GravityColors.bgFillSecondary
                    }
                }
            } else {
                GravityColors.bgFillSecondary
            }
        }
        .clipped()
    }
}

/// Merchant covers sometimes arrive as precomposed collection grids. The
/// image surface on a Shop card should be one uninterrupted scene; foreground
/// product tiles can communicate the assortment without baking a second grid
/// into the background.
private func singleLifestyleImageURL(for merchant: SampleMerchant) -> String? {
    // Vetted merchant-owned single frames. Runtime storefront covers are not
    // used here because several shops publish precomposed four-up collages as
    // their collection image, which reads like a broken card inside this UI.
    let curated: [String: String] = [
        "forom": "https://cdn.shopify.com/s/files/1/0356/2795/8403/files/gallerwallmirrorsandporcupine-beaunaySQ_1100x_66a7927f-7385-46bd-8697-ab807198137b.webp?v=1697392113",
        "standards-manual": "https://cdn.shopify.com/s/files/1/0883/7252/files/27_IMPACT_1_SPREADS_1_286f7e02-0e88-4fbf-9b1b-8c28fafa3557copy.jpg?v=1781188537",
        "fellow": "https://cdn.shopify.com/s/files/1/0057/6235/1219/products/Stagg-Tasting-Glasses-04.jpg?v=1757441377",
        "ceremonia": "https://cdn.shopify.com/s/files/1/0414/8301/0212/files/0332_Ceremonia_MELISSA_SH_18_HAIR_TOWEL_WHITE_036_1e1b8b67-b6fe-4c92-a226-6e761a160a24.jpg?v=1767030994",
        "moma": "https://cdn.shopify.com/s/files/1/0623/7962/2630/files/c122148b-8768-4c1a-83cf-b4fa3a7f2908.jpg?v=1768317967",
        "draw-down": "https://cdn.shopify.com/s/files/1/1681/2497/files/IMG_5981.jpg?v=1703088810",
        "extra-butter-salomon": "https://cdn.shopify.com/s/files/1/0236/4333/files/L47762000-2_66a3641c-5dc0-49c8-acbb-98b95c314627.jpg?v=1738004890",
    ]
    return curated[merchant.id]
        ?? merchant.products.lazy
            .flatMap(\.allImageURLs)
            .first
        ?? merchant.products.first?.imageURL
}

/// The evergreen Deals destination from the Hyperfeed reference. It keeps the
/// shared Home navigation in place and groups the buyer's real assortment by
/// merchant instead of introducing a second deal-specific catalog.
struct DealsDestinationFeed: View {
    let products: [ResolvedStoryProduct]
    let topInset: CGFloat
    @Binding var selectedBand: DealFilterBand
    var onFilterPinned: (Bool) -> Void

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var filtersArePinned = false

    private var sections: [BuyerDealSection] {
        var merchantOrder: [SampleMerchant] = []
        var buyerProductsByMerchant: [String: [SampleMerchant.Product]] = [:]

        for item in products {
            if buyerProductsByMerchant[item.merchant.id] == nil {
                merchantOrder.append(item.merchant)
            }
            buyerProductsByMerchant[item.merchant.id, default: []].append(item.product)
        }

        return merchantOrder.compactMap { merchant in
            var seen = Set<Int>()
            let resolvedProducts = (buyerProductsByMerchant[merchant.id, default: []] + merchant.products)
                .filter { seen.insert($0.id).inserted }
            guard !resolvedProducts.isEmpty else { return nil }

            return BuyerDealSection(
                merchant: merchant,
                products: Array(resolvedProducts.prefix(8)),
                reward: reward(for: merchant)
            )
        }
        .filter { selectedBand.includes($0.reward) }
        .prefix(10)
        .map { $0 }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                DealFilterTrain(selectedBand: $selectedBand)
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

                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(sections) { section in
                        DealMerchantRail(section: section, openProduct: openProduct)
                    }
                }
                .padding(.top, GravitySpacing.space16)
            }
            .padding(.top, topInset + 13)
            .padding(.bottom, FeedCardStyle.bottomNavigationClearance + 32)
        }
        .background(Color.white)
        .ignoresSafeArea(edges: .top)
        .onDisappear { onFilterPinned(false) }
    }

    private func reward(for merchant: SampleMerchant) -> Int {
        let stableSeed = merchant.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return [10, 20, 30][stableSeed % 3]
    }

    private func openProduct(_ merchant: SampleMerchant, _ product: SampleMerchant.Product) {
        coordinator.pushRoute(.product(merchantId: merchant.id, productId: product.id))
    }
}

struct DealFilterTrain: View {
    @Binding var selectedBand: DealFilterBand
    var showsStickyBackdrop = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space4) {
                Button {
                    HapticFeedback.light.fire()
                } label: {
                    Image(GravityIcon.filter.rawValue)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(GravityColors.text)
                        .frame(width: 40, height: 40)
                        .background(.white, in: Circle())
                        .overlay { Circle().strokeBorder(GravityColors.border, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filter deals")

                ForEach(DealFilterBand.allCases) { band in
                    Button {
                        HapticFeedback.selection.fire()
                        selectedBand = band
                    } label: {
                        Text(band.rawValue)
                            .gravityTextStyle(GravityTypography.buttonMedium)
                            .foregroundStyle(selectedBand == band ? .white : GravityColors.text)
                            .padding(.horizontal, GravitySpacing.space16)
                            .frame(height: 40)
                            .background(
                                selectedBand == band ? GravityColors.text : .white,
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().strokeBorder(GravityColors.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedBand == band ? .isSelected : [])
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .padding(.bottom, GravitySpacing.space8)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollClipDisabled()
        .background(alignment: .top) {
            if showsStickyBackdrop {
                StickyFilterBackdrop()
            }
        }
    }
}

enum DealFilterBand: String, CaseIterable, Identifiable {
    case all = "All"
    case small = "$5 - $10 off"
    case medium = "$10 - $20 off"
    case large = "$20 - $500 off"

    var id: String { rawValue }

    func includes(_ reward: Int) -> Bool {
        switch self {
        case .all: true
        case .small: reward <= 10
        case .medium: reward > 10 && reward <= 20
        case .large: reward > 20
        }
    }
}

private struct BuyerDealSection: Identifiable {
    let merchant: SampleMerchant
    let products: [SampleMerchant.Product]
    let reward: Int

    var id: String { merchant.id }
    var threshold: Int { reward >= 30 ? 60 : 50 }
}

private struct DealMerchantRail: View {
    let section: BuyerDealSection
    let openProduct: (SampleMerchant, SampleMerchant.Product) -> Void

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            merchantHeader
            productRail
        }
    }

    private var merchantHeader: some View {
        HStack(spacing: GravitySpacing.space10) {
            Button {
                HapticFeedback.light.fire()
                coordinator.pushRoute(.store(merchantId: section.merchant.id))
            } label: {
                MerchantAvatarView(
                    merchant: section.merchant,
                    size: 44,
                    borderColor: Color(hex: 0x6C4DFF),
                    borderWidth: 2
                )
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.light.fire()
                coordinator.pushRoute(.store(merchantId: section.merchant.id))
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.merchant.displayName)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(GravityColors.text)
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text("Earn $\(section.reward)")
                            .foregroundStyle(Color(hex: 0x5433EB))
                        Text(" on orders over $\(section.threshold)")
                            .foregroundStyle(GravityColors.text)
                    }
                    .gravityTextStyle(GravityTypography.editorialBody)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.light.fire()
            } label: {
                Image(GravityIcon.overflow.rawValue)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(GravityColors.text)
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More options for \(section.merchant.displayName)")
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
    }

    private var productRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                ForEach(section.products) { product in
                    Button {
                        HapticFeedback.light.fire()
                        openProduct(section.merchant, product)
                    } label: {
                        ProductCard(
                            image: nil,
                            imageURL: product.imageURL,
                            productName: product.title,
                            price: formatPrice(product.price),
                            showFavoriteButton: true
                        )
                        .frame(width: 116)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .frame(height: 156)
    }
}

/// Stable public-product references for Nari's first archive-fashion edit.
/// These are all already present in the sanitized shelf fixture; none comes
/// from protected account activity or a warehouse lookup.
enum NariDestinationCatalog {
    static let birthdayGiftStoryID = "ashten-nari-birthday-gift-guide"
    static let homeGiftTransitionSourceID = "home-nari-gift-guide"
    static let giftSurfaceHex = "#5B304A"
    static let heroImageURL = "https://www.viviennewestwood.com/dw/image/v2/BJGV_PRD/on/demandware.static/-/Library-Sites-viviennewestwood-global-content/default/dwe86a717f/images/plp/AW2627/Womens/PLP_inline%20content%20asset_AW2627_59.jpg?sw=1384&sh=1992&q=80"

    private static let bkrProductIDs: [Int] = [
        7_826_387_435_691,
        7_463_118_766_251,
        7_567_169_519_787,
        8_170_323_673_259,
        15_083_186_717_042,
        15_083_186_782_578,
    ]

    private static let archiveProductReferences: [(merchantID: String, productID: Int)] = [
        ("shelf-shop-atelier-new-york-067dba9", 6_432_601_627_424_205_942),
        ("shelf-shop-the-list-af09863", 6_584_303_631_024_519_751),
        ("shelf-shop-atelier-new-york-067dba9", 181_278_470_310_650_848),
        ("shelf-shop-dover-street-market-london-6ae9cc9", 82_355_939_247_087_383),
        ("shelf-shop-vorhe-9d1a65e", 861_327_334_310_274_434),
        ("shelf-shop-dover-street-market-london-6ae9cc9", 7_653_383_194_154_608_404),
        ("shelf-shop-dsmny-e-shop-8eed2d9", 5_410_557_038_914_398_204),
        ("shelf-shop-good-s-vintage-0aae91a", 1_206_355_286_448_168_800),
        ("shelf-shop-mano-vintage-jewellery-2b7e972", 5_290_697_848_581_136_884),
        ("shelf-shop-the-list-af09863", 2_520_498_729_746_342_356),
        ("shelf-shop-atelier-new-york-067dba9", 8_551_840_306_906_279_997),
        ("shelf-shop-lisa-leonard-designs-4e93435", 5_511_402_889_659_851_701),
        ("shelf-shop-mejuri-fd25dc3", 6_451_736_026_621_955_886),
        ("shelf-shop-otiumberg-96e3bcf", 9_215_536_010_869_585_658),
    ]

    /// The same full-height feed grammar as Leon's gift guide, authored for
    /// Nari with archive-fashion products and the Westwood campaign world.
    /// Visibility remains a Home-level occasion decision rather than a claim
    /// that the buyer's private activity was observed.
    static let birthdayGiftStory = FeedStory(
        id: birthdayGiftStoryID,
        eyebrow: "FOR NARI",
        title: "Holiday gifts for Nari",
        subtitle: "Archive fashion, sculptural jewelry, and a few unexpected finds picked for her.",
        format: .shortlist,
        topicKeys: ["gift", "style", "archive-fashion", "design"],
        accentHex: giftSurfaceHex,
        coverImageName: nil,
        destinationLabel: "Open Nari’s gift guide",
        products: archiveProductReferences.prefix(8).map {
            FeedStory.ProductReference(merchantID: $0.merchantID, productID: $0.productID)
        }
    )

    static func archiveProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        archiveProductReferences.compactMap { reference in
            guard let merchant = merchants.first(where: { $0.id == reference.merchantID }),
                  let product = merchant.products.first(where: { $0.id == reference.productID }) else {
                return nil
            }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }

    static func bkrProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        guard let merchant = merchants.first(where: { $0.id == "bkr" }) else { return [] }
        return bkrProductIDs.compactMap { productID in
            guard let product = merchant.products.first(where: { $0.id == productID }) else { return nil }
            return ResolvedStoryProduct(merchant: merchant, product: product)
        }
    }

    static func giftProducts(from merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        archiveProducts(from: merchants) + bkrProducts(from: merchants)
    }

    static func destinationMerchants(from merchants: [SampleMerchant]) -> [SampleMerchant] {
        LocalMerchantService.mergeMerchants([
            merchants,
            HypothesisShelfCatalog.merchants,
            BuyerPersonalizationCatalog.merchants.filter { $0.id == "bkr" },
        ])
    }
}

/// Local, user-editable context for Nari. These answers personalize the
/// prototype without implying that Shop inferred relationship or account data.
@Observable
final class NariProfilePreferences {
    enum BirthdayKnowledge: String, CaseIterable {
        case unanswered
        case known
        case approximate
    }

    enum Persona: String, CaseIterable, Identifiable {
        case archivist
        case collector
        case individualist
        case minimalist

        var id: Self { self }
        var title: String {
            switch self {
            case .archivist: "The Archivist"
            case .collector: "The Collector"
            case .individualist: "The Individualist"
            case .minimalist: "The Minimalist"
            }
        }
        var subtitle: String {
            switch self {
            case .archivist: "Rare pieces with a past"
            case .collector: "Jewelry and design objects"
            case .individualist: "Expressive, unexpected finds"
            case .minimalist: "Fewer, lasting pieces"
            }
        }
        var symbol: String {
            switch self {
            case .archivist: "archivebox.fill"
            case .collector: "sparkles"
            case .individualist: "wand.and.stars"
            case .minimalist: "circle.lefthalf.filled"
            }
        }
    }

    enum DiscoveryStyle: String, CaseIterable, Identifiable {
        case familiar
        case balanced
        case surprising

        var id: Self { self }
        var title: String {
            switch self {
            case .familiar: "Familiar"
            case .balanced: "A mix"
            case .surprising: "Surprising"
            }
        }
        var subtitle: String {
            switch self {
            case .familiar: "Stay close"
            case .balanced: "Some range"
            case .surprising: "Go left-field"
            }
        }
    }

    static let shared = NariProfilePreferences()

    private enum Key {
        static let birthdayKnowledge = "nariProfileBirthdayKnowledge"
        static let birthday = "nariProfileBirthday"
        static let birthdayYearKnown = "nariProfileBirthdayYearKnown"
        static let approximateAge = "nariProfileApproximateAge"
        static let persona = "nariProfilePersona"
        static let interests = "nariProfileInterests"
        static let priorities = "nariProfilePriorities"
        static let discoveryStyle = "nariProfileDiscoveryStyle"
        static let relationship = "nariFeedRelationship"
        static let clothingSize = "nariProfileClothingSize"
        static let pantsSize = "nariProfilePantsSize"
        static let dressSize = "nariProfileDressSize"
        static let shoeSize = "nariProfileShoeSize"
        static let fitNotes = "nariProfileFitNotes"
        static let seededShoppingDetails = "nariProfileSeededShoppingDetailsV2"
    }

    private let defaults: UserDefaults

    var birthdayKnowledge: BirthdayKnowledge {
        didSet { defaults.set(birthdayKnowledge.rawValue, forKey: Key.birthdayKnowledge) }
    }
    var birthday: Date? {
        didSet { defaults.set(birthday, forKey: Key.birthday) }
    }
    var birthdayYearKnown: Bool {
        didSet { defaults.set(birthdayYearKnown, forKey: Key.birthdayYearKnown) }
    }
    var approximateAge: Double {
        didSet { defaults.set(approximateAge, forKey: Key.approximateAge) }
    }
    var persona: Persona? {
        didSet {
            if let persona {
                defaults.set(persona.rawValue, forKey: Key.persona)
            } else {
                defaults.removeObject(forKey: Key.persona)
            }
        }
    }
    var interests: [String] {
        didSet { defaults.set(interests, forKey: Key.interests) }
    }
    var priorities: [String] {
        didSet { defaults.set(priorities, forKey: Key.priorities) }
    }
    var discoveryStyle: DiscoveryStyle? {
        didSet {
            if let discoveryStyle {
                defaults.set(discoveryStyle.rawValue, forKey: Key.discoveryStyle)
            } else {
                defaults.removeObject(forKey: Key.discoveryStyle)
            }
        }
    }
    var relationship: String {
        didSet { defaults.set(relationship, forKey: Key.relationship) }
    }
    var clothingSize: String {
        didSet { defaults.set(clothingSize, forKey: Key.clothingSize) }
    }
    var pantsSize: String {
        didSet { defaults.set(pantsSize, forKey: Key.pantsSize) }
    }
    var dressSize: String {
        didSet { defaults.set(dressSize, forKey: Key.dressSize) }
    }
    var shoeSize: String {
        didSet { defaults.set(shoeSize, forKey: Key.shoeSize) }
    }
    var fitNotes: String {
        didSet { defaults.set(fitNotes, forKey: Key.fitNotes) }
    }
    var recommendationRevision = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        birthdayKnowledge = BirthdayKnowledge(
            rawValue: defaults.string(forKey: Key.birthdayKnowledge) ?? ""
        ) ?? .unanswered
        let storedBirthday = defaults.object(forKey: Key.birthday) as? Date
        birthday = storedBirthday
        birthdayYearKnown = defaults.object(forKey: Key.birthdayYearKnown) == nil
            ? storedBirthday != nil
            : defaults.bool(forKey: Key.birthdayYearKnown)
        approximateAge = defaults.object(forKey: Key.approximateAge) == nil
            ? 30
            : defaults.double(forKey: Key.approximateAge)
        persona = Persona(rawValue: defaults.string(forKey: Key.persona) ?? "")
        interests = defaults.stringArray(forKey: Key.interests) ?? []
        priorities = defaults.stringArray(forKey: Key.priorities) ?? []
        discoveryStyle = DiscoveryStyle(rawValue: defaults.string(forKey: Key.discoveryStyle) ?? "")
        relationship = defaults.string(forKey: Key.relationship) ?? "Partner"
        let storedClothingSize = defaults.string(forKey: Key.clothingSize) ?? ""
        if defaults.bool(forKey: Key.seededShoppingDetails) {
            clothingSize = storedClothingSize
        } else {
            clothingSize = storedClothingSize.isEmpty ? "S" : storedClothingSize
            defaults.set(true, forKey: Key.seededShoppingDetails)
        }
        pantsSize = defaults.string(forKey: Key.pantsSize) ?? ""
        dressSize = defaults.string(forKey: Key.dressSize) ?? ""
        shoeSize = defaults.string(forKey: Key.shoeSize) ?? ""
        fitNotes = defaults.string(forKey: Key.fitNotes) ?? ""
    }

    var resolvedAge: Int? {
        switch birthdayKnowledge {
        case .known:
            guard birthdayYearKnown, let birthday else { return nil }
            return max(0, Calendar.current.dateComponents([.year], from: birthday, to: Date()).year ?? 0)
        case .approximate:
            return Int(approximateAge)
        case .unanswered:
            return nil
        }
    }

    var hasShoppingDetails: Bool {
        relationship != "Partner"
            || !clothingSize.isEmpty
            || !pantsSize.isEmpty
            || !dressSize.isEmpty
            || !shoeSize.isEmpty
            || !fitNotes.isEmpty
    }

    /// Birthdays are recurring occasions, so the stored year is used only to
    /// validate the original date and the next month/day occurrence drives
    /// promotion. A 45-day window is early enough for considered gifting
    /// without making the homepage card feel permanently pinned.
    func hasUpcomingBirthday(
        from referenceDate: Date = Date(),
        withinDays: Int = 45,
        calendar inputCalendar: Calendar = .current
    ) -> Bool {
        guard birthdayKnowledge == .known,
              let birthday,
              withinDays >= 0 else { return false }

        let calendar = inputCalendar
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let birthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
        guard let month = birthdayComponents.month,
              let requestedDay = birthdayComponents.day else { return false }

        let referenceYear = calendar.component(.year, from: referenceDay)
        for year in referenceYear...(referenceYear + 1) {
            var monthComponents = DateComponents()
            monthComponents.calendar = calendar
            monthComponents.timeZone = calendar.timeZone
            monthComponents.year = year
            monthComponents.month = month
            monthComponents.day = 1
            guard let monthStart = calendar.date(from: monthComponents),
                  let validDays = calendar.range(of: .day, in: .month, for: monthStart) else {
                continue
            }

            var occurrenceComponents = monthComponents
            occurrenceComponents.day = min(requestedDay, validDays.count)
            guard let occurrence = calendar.date(from: occurrenceComponents) else { continue }
            let occurrenceDay = calendar.startOfDay(for: occurrence)
            guard occurrenceDay >= referenceDay else { continue }
            let daysUntil = calendar.dateComponents(
                [.day],
                from: referenceDay,
                to: occurrenceDay
            ).day ?? Int.max
            return daysUntil <= withinDays
        }

        return false
    }

    var giftGuideContext: GiftGuidePersonalizationContext {
        GiftGuidePersonalizationContext(
            age: resolvedAge.map(Double.init),
            personaID: persona?.rawValue,
            personaTitle: persona?.title,
            interests: interests,
            priorities: priorities,
            discoveryStyleID: discoveryStyle?.rawValue
        )
    }

    func toggleInterest(_ interest: String) {
        if interests.contains(interest) {
            interests.removeAll { $0 == interest }
        } else {
            interests.append(interest)
        }
    }

    func addInterest(_ interest: String) {
        let trimmed = interest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !interests.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return
        }
        interests.append(trimmed)
    }

#if DEBUG
    func resetQuizForDemo() {
        birthdayKnowledge = .unanswered
        birthday = nil
        birthdayYearKnown = false
        approximateAge = 30
        persona = nil
        interests = []
        priorities = []
        discoveryStyle = nil
    }

    func resetForVisualQA() {
        resetQuizForDemo()
        relationship = "Partner"
        clothingSize = "S"
        pantsSize = ""
        dressSize = ""
        shoeSize = ""
        fitNotes = ""
    }
#endif

    func togglePriority(_ priority: String) {
        if priorities.contains(priority) {
            priorities.removeAll { $0 == priority }
        } else {
            priorities.append(priority)
        }
    }

    func recommendationScore(for item: ResolvedStoryProduct) -> Int {
        let text = ([
            item.product.title,
            item.product.productType ?? "",
            item.product.productDescription ?? "",
            item.merchant.displayName,
        ] + item.product.tags)
            .joined(separator: " ")
            .lowercased()
        var score = 0
        let ignoredTerms: Set<String> = ["and", "for", "from", "into", "the", "with"]
        let interestTerms = interests
            .flatMap { $0.lowercased().split { !$0.isLetter && !$0.isNumber } }
            .map(String.init)
            .filter { $0.count > 3 && !ignoredTerms.contains($0) }
        score += interestTerms.reduce(0) { $0 + (text.contains($1) ? 28 : 0) }

        if let persona {
            let personaTerms: [String]
            switch persona {
            case .archivist:
                personaTerms = ["archive", "vintage", "watch", "jewelry", "leather", "design"]
            case .collector:
                personaTerms = [
                    "ring", "jewelry", "jewellery", "earring", "cuff", "brooch",
                    "watch", "object", "edition", "design",
                ]
            case .individualist:
                personaTerms = ["neon", "comic", "robot", "sculptural", "color", "statement"]
            case .minimalist:
                personaTerms = ["minimal", "classic", "stainless", "black", "design", "useful"]
            }
            score += personaTerms.reduce(0) { $0 + (text.contains($1) ? 22 : 0) }
        }

        if resolvedAge != nil,
           ["kids", "child", "toy", "dinosaur"].contains(where: text.contains) {
            score -= 60
        }
        if discoveryStyle == .surprising,
           ["neon", "robot", "ring", "comic", "sculptural"].contains(where: text.contains) {
            score += 18
        }
        return score
    }
}

/// A destination for shopping for Nari. Optional profile details remain local;
/// the products remain public prototype data.
struct NariDestinationFeed: View {
    let giftProducts: [ResolvedStoryProduct]
    let archiveProducts: [ResolvedStoryProduct]
    let topInset: CGFloat
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var profile = NariProfilePreferences.shared
#if DEBUG
    @State private var showsShoppingDetails = ProcessInfo.processInfo.arguments.contains("-openNariDetails")
#else
    @State private var showsShoppingDetails = false
#endif
#if DEBUG
    @State private var showsProfileEditor = ProcessInfo.processInfo.arguments.contains("-openNariProfile")
#else
    @State private var showsProfileEditor = false
#endif
    @State private var showsProfilePrompt = true
    @State private var scrollTarget: String?
    @State private var recommendationUpdatePhase = RecommendationUpdatePhase.idle
    @State private var recommendationUpdateTask: Task<Void, Never>?

    private let profilePromptHeight: CGFloat = 56
    private let profilePromptBottomInset = GravitySpacing.space64 + GravitySpacing.space8

    private let jewelryAndSecondhandMerchantIDs: Set<String> = [
        "shelf-shop-good-s-vintage-0aae91a",
        "shelf-shop-lisa-leonard-designs-4e93435",
        "shelf-shop-mano-vintage-jewellery-2b7e972",
        "shelf-shop-mejuri-fd25dc3",
        "shelf-shop-otiumberg-96e3bcf",
        "shelf-shop-the-list-af09863",
    ]
    private let minimumProductsPerRecommendationRail = 4

    private enum RecommendationRail: Hashable {
        case archive
        case jewelry
        case everydayDesign
    }

    private enum RecommendationUpdatePhase: Equatable {
        case idle
        case refreshing
        case updated
    }

    private var isRefreshingRecommendations: Bool {
        recommendationUpdatePhase == .refreshing
    }

    private func productKey(for item: ResolvedStoryProduct) -> String {
        let imageURL = item.product.imageURL ?? ""
        let normalizedImageURL = imageURL
            .split(separator: "?", maxSplits: 1)
            .first
            .map(String.init) ?? imageURL
        return normalizedImageURL.isEmpty
            ? "\(item.merchant.id):\(item.product.id)"
            : normalizedImageURL
    }

    private func uniqueProducts(
        _ products: [ResolvedStoryProduct],
        excluding excludedKeys: Set<String> = []
    ) -> [ResolvedStoryProduct] {
        var seenKeys = excludedKeys
        return products.filter { seenKeys.insert(productKey(for: $0)).inserted }
    }

    private var giftPreviewProducts: [ResolvedStoryProduct] {
        let ranked = personalizedGiftProducts
        var remainingCounts = Dictionary(
            grouping: ranked,
            by: recommendationRail(for:)
        ).mapValues(\.count)
        var preview: [ResolvedStoryProduct] = []

        // The gift preview can still react to profile changes, but it may only
        // borrow from a category while that category keeps a complete rail.
        // This prevents a jewelry-heavy profile from leaving the secondhand
        // section with a single stranded product.
        for item in ranked {
            let rail = recommendationRail(for: item)
            guard remainingCounts[rail, default: 0] > minimumProductsPerRecommendationRail else {
                continue
            }
            preview.append(item)
            remainingCounts[rail, default: 0] -= 1
            if preview.count == 3 { break }
        }
        return preview
    }

    private var giftPreviewProductKeys: Set<String> {
        Set(giftPreviewProducts.map(productKey(for:)))
    }

    private var giftPreviewSubtitle: String {
        if profile.persona != nil
            || !profile.interests.isEmpty
            || !profile.priorities.isEmpty
            || profile.discoveryStyle != nil {
            return "Tuned to her taste"
        }
        return "A shortlist shaped around her style"
    }

    private var jewelryProducts: [ResolvedStoryProduct] {
        let ranked = archiveProducts
            .enumerated()
            .filter { jewelryAndSecondhandMerchantIDs.contains($0.element.merchant.id) }
            .sorted { lhs, rhs in
                let lhsScore = profile.recommendationScore(for: lhs.element)
                let rhsScore = profile.recommendationScore(for: rhs.element)
                return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
            }
            .map(\.element)
        let excludedKeys = giftPreviewProductKeys.union(archiveRailProductKeys)
        return uniqueProducts(ranked, excluding: excludedKeys)
    }

    private var bkrProducts: [ResolvedStoryProduct] {
        let excludedKeys = giftPreviewProductKeys
            .union(archiveRailProductKeys)
            .union(Set(jewelryProducts.map(productKey(for:))))
        return uniqueProducts(
            giftProducts.filter { $0.merchant.id == "bkr" },
            excluding: excludedKeys
        )
    }

    private var personalizedGiftProducts: [ResolvedStoryProduct] {
        let ranked = giftProducts.enumerated().sorted { lhs, rhs in
            let lhsScore = profile.recommendationScore(for: lhs.element)
            let rhsScore = profile.recommendationScore(for: rhs.element)
            return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
        }.map(\.element)
        return uniqueProducts(ranked)
    }

    private var archiveRailProducts: [ResolvedStoryProduct] {
        let preferredIDs = [
            1_206_355_286_448_168_800,
            5_290_697_848_581_136_884,
            861_327_334_310_274_434,
            5_410_557_038_914_398_204,
            2_520_498_729_746_342_356,
            8_551_840_306_906_279_997,
        ]
        let preferredProducts = preferredIDs.compactMap { productID in
            archiveProducts.first {
                $0.product.id == productID
                    && !jewelryAndSecondhandMerchantIDs.contains($0.merchant.id)
            }
        }
        let preferredProductIDs = Set(preferredProducts.map(\.id))
        let remainingProducts = archiveProducts.filter {
            !preferredProductIDs.contains($0.id)
                && !jewelryAndSecondhandMerchantIDs.contains($0.merchant.id)
        }
        let ranked = (preferredProducts + remainingProducts).enumerated().sorted { lhs, rhs in
            let lhsScore = profile.recommendationScore(for: lhs.element)
            let rhsScore = profile.recommendationScore(for: rhs.element)
            return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
        }.map(\.element)
        return uniqueProducts(ranked, excluding: giftPreviewProductKeys)
    }

    private var archiveRailProductKeys: Set<String> {
        Set(archiveRailProducts.map(productKey(for:)))
    }

    private func recommendationRail(for item: ResolvedStoryProduct) -> RecommendationRail {
        if item.merchant.id == "bkr" {
            return .everydayDesign
        }
        if jewelryAndSecondhandMerchantIDs.contains(item.merchant.id) {
            return .jewelry
        }
        return .archive
    }

    var body: some View {
        GeometryReader { geometry in
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                profileHeader

                NariGiftGuideCard(
                    products: giftPreviewProducts,
                    subtitle: giftPreviewSubtitle,
                    isRefreshing: isRefreshingRecommendations,
                    namespace: namespace,
                    openGuide: openGiftGuide
                )
                .padding(.horizontal, GravitySpacing.space12)
                .containerRelativeFrame(.horizontal)
                .padding(.top, GravitySpacing.space24)

                NariProductRail(
                    title: "Archive pieces",
                    subtitle: "Strong silhouettes, rare details, and independent designers",
                    products: archiveRailProducts,
                    isRefreshing: isRefreshingRecommendations,
                    openProduct: openProduct
                )
                .padding(.top, 28)

                HStack(spacing: 0) {
                    NariArchiveEditorialCard(
                        namespace: namespace,
                        openEdit: openArchiveEdit
                    )
                }
                .frame(width: max(0, geometry.size.width - (GravitySpacing.space16 * 2)))
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.vertical, GravitySpacing.space20)
                .id("nari-editorial")

                NariProductRail(
                    title: "Jewelry and vintage finds",
                    subtitle: "Sculptural pieces and secondhand fashion",
                    products: jewelryProducts,
                    isRefreshing: isRefreshingRecommendations,
                    openProduct: openProduct
                )
                .padding(.top, 28)

                NariProductRail(
                    title: "Everyday design",
                    subtitle: "BKR bottles in colors she might love",
                    products: bkrProducts,
                    isRefreshing: isRefreshingRecommendations,
                    openProduct: openProduct
                )
                .padding(.top, 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, topInset + GravitySpacing.space20)
            .padding(
                .bottom,
                profilePromptBottomInset + profilePromptHeight + GravitySpacing.space24
            )
            .animation(.easeOut(duration: 0.22), value: profile.recommendationRevision)
        }
        .scrollPosition(id: $scrollTarget, anchor: .center)
        .background(Color.white)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, geometry.contentOffset.y + geometry.contentInsets.top)
        } action: { oldOffset, newOffset in
            if newOffset <= GravitySpacing.space8 {
                guard !showsProfilePrompt else { return }
                withAnimation(.easeOut(duration: 0.16)) {
                    showsProfilePrompt = true
                }
            } else if newOffset - oldOffset > 2, showsProfilePrompt {
                withAnimation(.easeOut(duration: 0.16)) {
                    showsProfilePrompt = false
                }
            } else if oldOffset - newOffset > 2, !showsProfilePrompt {
                withAnimation(.easeOut(duration: 0.16)) {
                    showsProfilePrompt = true
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            Group {
                if recommendationUpdatePhase == .idle {
                    NariProfilePromptBar {
                        HapticFeedback.light.fire()
                        showsProfileEditor = true
                    }
                    .offset(y: showsProfilePrompt ? 0 : profilePromptHeight + GravitySpacing.space24)
                    .opacity(showsProfilePrompt ? 1 : 0)
                    .allowsHitTesting(showsProfilePrompt)
                    .transition(.opacity)
                } else {
                    recommendationUpdateBar
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.bottom, profilePromptBottomInset)
        }
        .sheet(isPresented: $showsShoppingDetails) {
            NariShoppingDetailsEditor(profile: profile)
                .presentationDetents([.fraction(0.78)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
                .presentationBackground(.ultraThinMaterial)
                .environment(\.colorScheme, .light)
        }
        .sheet(isPresented: $showsProfileEditor) {
            NariProfileEditor(
                profile: profile,
                products: archiveProducts + personalizedGiftProducts,
                onSave: refreshRecommendations
            )
                .presentationDetents([.fraction(0.87)])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .environment(\.colorScheme, .light)
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-resetNariProfile") {
                profile.resetForVisualQA()
            }
            if ProcessInfo.processInfo.arguments.contains("-openNariEditorial") {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(500))
                    scrollTarget = "nari-editorial"
                }
            }
#endif
        }
        .task {
            guard let heroURL = URL(string: NariDestinationCatalog.heroImageURL) else { return }
            await ImageURLCache.shared.prefetch([heroURL])
        }
        .onDisappear {
            recommendationUpdateTask?.cancel()
            recommendationUpdateTask = nil
        }
        }
    }

    private var recommendationUpdateBar: some View {
        HStack(spacing: GravitySpacing.space10) {
            if recommendationUpdatePhase == .refreshing {
                ProgressView()
                    .controlSize(.small)
                    .tint(GravityColors.text)
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(GravityColors.text, in: Circle())
            }

            Text(
                recommendationUpdatePhase == .refreshing
                    ? "Refreshing Nari’s picks…"
                    : "Nari’s picks are updated"
            )
            .gravityTextStyle(GravityTypography.bodyLarge)
            .foregroundStyle(GravityColors.text)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, GravitySpacing.space16)
        .frame(maxWidth: .infinity)
        .frame(height: profilePromptHeight)
        .background(.ultraThinMaterial, in: Capsule())
        .glassEffect(
            .regular.tint(.black.opacity(0.07)),
            in: .capsule
        )
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.42), lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.small)
        .accessibilityLabel(
            recommendationUpdatePhase == .refreshing
                ? "Refreshing Nari's picks"
                : "Nari's picks are updated"
        )
    }

    private func refreshRecommendations() {
        recommendationUpdateTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            recommendationUpdatePhase = .refreshing
        }

        recommendationUpdateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.22)) {
                recommendationUpdatePhase = .updated
            }

            try? await Task.sleep(for: .milliseconds(1_400))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.16)) {
                recommendationUpdatePhase = .idle
            }
            recommendationUpdateTask = nil
        }
    }

    private var profileHeader: some View {
        HStack(spacing: GravitySpacing.space12) {
            Image("nari-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                Text("Shopping for")
                    .gravityTextStyle(GravityTypography.bodyLarge)
                    .foregroundStyle(GravityColors.textTertiary)
                Text("Nari")
                    .font(GravityFont.bold.fixedFont(size: 32))
                    .tracking(GravityLetterSpacing.slammed)
                    .foregroundStyle(GravityColors.text)
            }

            Spacer(minLength: GravitySpacing.space8)

            Button {
                HapticFeedback.light.fire()
                showsShoppingDetails = true
            } label: {
                Text(profile.hasShoppingDetails ? "Edit details" : "Add details")
                    .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(GravityColors.text)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.035), radius: 10, y: 4)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.97))
            .accessibilityLabel(profile.hasShoppingDetails ? "Edit Nari's size details" : "Add Nari's size details")
        }
        .padding(.horizontal, GravitySpacing.space16)
    }

    private func openProduct(_ item: ResolvedStoryProduct) {
        HapticFeedback.light.fire()
        coordinator.pushRoute(
            .product(merchantId: item.merchant.id, productId: item.product.id)
        )
    }

    private func openGiftGuide() {
        HapticFeedback.light.fire()
        coordinator.pushRoute(
            .story(
                storyId: HypothesisShelfCatalog.giftGuideStoryID,
                sourceId: "nari-gift-guide",
                giftRecipientName: "Nari"
            )
        )
    }

    private func openArchiveEdit() {
        HapticFeedback.light.fire()
        coordinator.pushRoute(
            .story(
                storyId: HypothesisShelfCatalog.giftGuideStoryID,
                sourceId: "nari-westwood-edit",
                giftRecipientName: "Nari"
            )
        )
    }
}

struct NariProfilePromptBar: View {
    let title: String
    let accessibilityLabel: String
    let waveformColor: Color
    let openProfile: () -> Void

    init(
        title: String = "Personalize Nari’s picks",
        accessibilityLabel: String = "Personalize Nari’s picks",
        waveformColor: Color = .black.opacity(0.82),
        openProfile: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.waveformColor = waveformColor
        self.openProfile = openProfile
    }

    var body: some View {
        Button(action: openProfile) {
            HStack(spacing: GravitySpacing.space8) {
                GravityIcon.plusSign.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(GravityColors.textTertiary)

                Text(title)
                    .gravityTextStyle(GravityTypography.bodyLarge)
                    .foregroundStyle(GravityColors.textPlaceholder)

                Spacer(minLength: GravitySpacing.space8)

                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(waveformColor)
            }
            .padding(.horizontal, GravitySpacing.space16)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.ultraThinMaterial, in: Capsule())
            .glassEffect(
                .regular.interactive().tint(.black.opacity(0.07)),
                in: .capsule
            )
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(0.42), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .accessibilityLabel(accessibilityLabel)
    }
}

struct NariGiftGuideBottomDock: View {
    @Bindable var state: GiftGuidePrototypeState
    let recipient: GiftGuideRecipient

    @State private var profile = NariProfilePreferences.shared
    @State private var showsBirthdayEditor = false

    var body: some View {
        NariProfilePromptBar(
            title: "When is Nari’s birthday?",
            accessibilityLabel: "Add Nari’s birthday",
            waveformColor: .white
        ) {
            HapticFeedback.light.fire()
            showsBirthdayEditor = true
        }
        .padding(.horizontal, GravitySpacing.space16)
        .sheet(isPresented: $showsBirthdayEditor) {
            NariBirthdayEditor(
                profile: profile,
                prefillsExistingBirthday: false
            )
            .presentationDetents([.height(128)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(Color.white)
            .environment(\.colorScheme, .light)
        }
    }
}

/// Shared geometry for the Nari profile sheets. Titles stay optically centered
/// and reserve the leading control width so longer copy never collides with it.
private struct NariSheetHeader: View {
    let title: Text
    var subtitle: String? = nil
    var backAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: GravitySpacing.space8) {
            ZStack {
                title
                    .gravityTextStyle(GravityTypography.headerExtraBold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, backAction == nil ? 0 : 56)

                if let backAction {
                    HStack {
                        Button(action: backAction) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(GravityColors.text)
                                .frame(width: 40, height: 40)
                                .background(Color.white, in: Circle())
                                .overlay {
                                    Circle().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5)
                                }
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 40)

            if let subtitle {
                Text(subtitle)
                    .gravityTextStyle(GravityTypography.bodyLarge)
                    .foregroundStyle(GravityColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NariProfileEditor: View {
    @Bindable var profile: NariProfilePreferences
    let products: [ResolvedStoryProduct]
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var approximateAge: Double
    @State private var selectedPersona: NariProfilePreferences.Persona?
    @State private var selectedInterests: [String]
    @State private var selectedPriorities: [String]
    @State private var selectedDiscoveryStyle: NariProfilePreferences.DiscoveryStyle?
    @State private var birthdayQuestionState: NariProfilePreferences.BirthdayKnowledge = .unanswered
    @State private var birthdayMonth = ""
    @State private var birthdayDay = ""
    @State private var birthdayYear = ""
    @State private var addsCustomInterest = false
    @State private var customInterest = ""
    @FocusState private var interestFieldFocused: Bool

    private let suggestedInterests = [
        "Vivienne Westwood",
        "Archive fashion",
        "Vintage jewelry",
        "Independent designers",
        "Interiors",
        "Art books",
        "One-off accessories",
    ]
    private let recommendationPriorities = [
        "Provenance",
        "Condition",
        "Original details",
        "Independent sellers",
        "Price",
        "Sustainability",
    ]

    init(
        profile: NariProfilePreferences,
        products: [ResolvedStoryProduct],
        onSave: @escaping () -> Void
    ) {
        self.profile = profile
        self.products = products
        self.onSave = onSave
        _approximateAge = State(initialValue: 30)
        _selectedPersona = State(initialValue: nil)
        _selectedInterests = State(initialValue: [])
        _selectedPriorities = State(initialValue: [])
        _selectedDiscoveryStyle = State(initialValue: nil)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header
                birthdayQuestion
                    .padding(.top, 32)
                personaQuestion
                    .padding(.top, 34)
                interestsQuestion
                    .padding(.top, 40)
                prioritiesQuestion
                    .padding(.top, 36)
                discoveryQuestion
                    .padding(.top, 36)
                quizSaveButton
                    .padding(.top, 40)
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, 34)
            .padding(.bottom, GravitySpacing.space32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            birthdayQuestionState = .unanswered
            birthdayMonth = ""
            birthdayDay = ""
            birthdayYear = ""
            approximateAge = 30
            selectedPersona = nil
            selectedInterests = []
            selectedPriorities = []
            selectedDiscoveryStyle = nil
            addsCustomInterest = false
            customInterest = ""
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-openNariBirthdayEntry") {
                birthdayQuestionState = .known
            } else if ProcessInfo.processInfo.arguments.contains("-openNariAgeSlider") {
                birthdayQuestionState = .approximate
            } else if ProcessInfo.processInfo.arguments.contains("-openNariBirthdayQuestion") {
                birthdayQuestionState = .unanswered
            }
#endif
        }
    }

    private var header: some View {
        NariSheetHeader(
            title:
                (
                Text("Tell us more about ")
                    .foregroundColor(GravityColors.text)
                + Text("Nari")
                    .foregroundColor(GravityColors.textTertiary)
                ),
            subtitle: "A few details make her recommendations better"
        )
    }

    private var birthdayQuestion: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            switch birthdayQuestionState {
            case .unanswered:
                (
                    Text("Do you know ")
                        .foregroundColor(GravityColors.text)
                    + Text("Nari’s")
                        .foregroundColor(GravityColors.textTertiary)
                    + Text(" birthday?")
                        .foregroundColor(GravityColors.text)
                )
                    .gravityTextStyle(GravityTypography.subtitle)

                HStack(spacing: GravitySpacing.space8) {
                    answerButton("Yes") {
                        HapticFeedback.selection.fire()
                        birthdayMonth = ""
                        birthdayDay = ""
                        birthdayYear = ""
                        withAnimation(.easeOut(duration: 0.18)) {
                            birthdayQuestionState = .known
                        }
                    }
                    answerButton("No") {
                        HapticFeedback.selection.fire()
                        withAnimation(.easeOut(duration: 0.20)) {
                            birthdayQuestionState = .approximate
                        }
                    }
                }

            case .known:
                VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                    (
                        Text("What’s ")
                            .foregroundColor(GravityColors.text)
                        + Text("Nari’s")
                            .foregroundColor(GravityColors.textTertiary)
                        + Text(" birthday?")
                            .foregroundColor(GravityColors.text)
                    )
                    .gravityTextStyle(GravityTypography.subtitle)

                    NariBirthdayFields(
                        month: $birthdayMonth,
                        day: $birthdayDay,
                        year: $birthdayYear
                    )
                    .frame(height: 50)

                    Text("We’ll use it to time gift ideas")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(GravityColors.textPlaceholder)
                }

            case .approximate:
                VStack(alignment: .leading, spacing: GravitySpacing.space6) {
                    HStack(spacing: GravitySpacing.space4) {
                        (
                            Text("How old is ")
                                .foregroundColor(GravityColors.text)
                            + Text("Nari")
                                .foregroundColor(GravityColors.textTertiary)
                            + Text("?")
                                .foregroundColor(GravityColors.text)
                        )
                            .gravityTextStyle(GravityTypography.subtitle)
                        Spacer(minLength: 0)
                        Text("\(Int(approximateAge)) years old")
                            .gravityTextStyle(GravityTypography.bodyLarge)
                            .foregroundStyle(GravityColors.text)
                    }
                    NariAgeSlider(value: $approximateAge)
                }
            }
        }
        .animation(.easeOut(duration: 0.20), value: birthdayQuestionState)
    }

    private var quizSaveButton: some View {
        Button {
            if birthdayQuestionState == .known, let birthday = inlineParsedBirthday {
                profile.birthday = birthday
                profile.birthdayYearKnown = !birthdayYear.isEmpty
                profile.birthdayKnowledge = .known
            } else if birthdayQuestionState == .approximate {
                profile.birthdayKnowledge = .approximate
            }
            profile.approximateAge = approximateAge
            profile.persona = selectedPersona
            profile.interests = selectedInterests
            profile.priorities = selectedPriorities
            profile.discoveryStyle = selectedDiscoveryStyle
            HapticFeedback.light.fire()
            profile.recommendationRevision += 1
            onSave()
            dismiss()
        } label: {
            Text("Save")
                .gravityTextStyle(GravityTypography.buttonLarge)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(GravityColors.text, in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
    }

    private var inlineParsedBirthday: Date? {
        guard let monthValue = Int(birthdayMonth),
              let dayValue = Int(birthdayDay) else { return nil }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let hasYear = !birthdayYear.isEmpty
        let yearValue: Int
        if hasYear {
            guard birthdayYear.count == 4,
                  let suppliedYear = Int(birthdayYear),
                  (currentYear - 120)...currentYear ~= suppliedYear else { return nil }
            yearValue = suppliedYear
        } else {
            yearValue = 2000
        }

        var components = DateComponents()
        components.calendar = calendar
        components.year = yearValue
        components.month = monthValue
        components.day = dayValue
        components.hour = 12
        guard let date = calendar.date(from: components),
              !hasYear || date <= Date() else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == yearValue,
              resolved.month == monthValue,
              resolved.day == dayValue else { return nil }
        return date
    }

    private var personaQuestion: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            (
                Text("What best describes ")
                    .foregroundColor(GravityColors.text)
                + Text("Nari")
                    .foregroundColor(GravityColors.textTertiary)
                + Text("?")
                    .foregroundColor(GravityColors.text)
            )
                .gravityTextStyle(GravityTypography.subtitle)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: GravitySpacing.space8), count: 2),
                spacing: GravitySpacing.space12
            ) {
                ForEach(NariProfilePreferences.Persona.allCases) { persona in
                    let isSelected = selectedPersona == persona
                    Button {
                        HapticFeedback.selection.fire()
                        selectedPersona = isSelected ? nil : persona
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 0) {
                                Spacer(minLength: GravitySpacing.space8)
                                NariPersonaArtwork(persona: persona, products: products)
                                    .frame(height: 96)
                                Spacer(minLength: GravitySpacing.space4)
                                Text(persona.title)
                                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                                    .foregroundStyle(GravityColors.text)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: GravitySpacing.space10)
                            }

                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(GravityColors.text, in: Circle())
                                    .padding(GravitySpacing.space10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 158)
                        .background(GravityColors.bgFillSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                                .strokeBorder(
                                    isSelected ? GravityColors.text : .clear,
                                    lineWidth: 1.5
                                )
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var interestsQuestion: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            (
                Text("What is ")
                    .foregroundColor(GravityColors.text)
                + Text("Nari")
                    .foregroundColor(GravityColors.textTertiary)
                + Text(" into lately?")
                    .foregroundColor(GravityColors.text)
            )
                .gravityTextStyle(GravityTypography.subtitle)

            NariFlowLayout(spacing: GravitySpacing.space8) {
                ForEach(allInterestOptions, id: \.self) { interest in
                    selectionChip(
                        interest,
                        isSelected: selectedInterests.contains(interest)
                    ) {
                        HapticFeedback.selection.fire()
                        toggleInterest(interest)
                    }
                }

                addInterestButton
            }

            if addsCustomInterest {
                HStack(spacing: GravitySpacing.space8) {
                    TextField("Add something specific", text: $customInterest)
                        .gravityTextStyle(GravityTypography.bodySmall)
                        .focused($interestFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addCustomInterest)

                    Button("Add", action: addCustomInterest)
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .disabled(customInterest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, GravitySpacing.space12)
                .frame(height: 44)
                .background(GravityColors.bgFillSecondary, in: Capsule())
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var prioritiesQuestion: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            (
                Text("What should we prioritize for ")
                    .foregroundColor(GravityColors.text)
                + Text("Nari")
                    .foregroundColor(GravityColors.textTertiary)
                + Text("?")
                    .foregroundColor(GravityColors.text)
            )
                .gravityTextStyle(GravityTypography.subtitle)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: GravitySpacing.space8),
                    GridItem(.flexible(), spacing: GravitySpacing.space8),
                ],
                spacing: GravitySpacing.space8
            ) {
                ForEach(recommendationPriorities, id: \.self) { priority in
                    let isSelected = selectedPriorities.contains(priority)
                    Button {
                        HapticFeedback.selection.fire()
                        togglePriority(priority)
                    } label: {
                        HStack(spacing: GravitySpacing.space10) {
                            priorityIcon(for: priority).image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                                .foregroundStyle(isSelected ? .white : GravityColors.text)
                                .frame(width: 34, height: 34)
                                .background(
                                    isSelected ? .white.opacity(0.16) : .black.opacity(0.045),
                                    in: Circle()
                                )

                            Text(priority)
                                .gravityTextStyle(GravityTypography.bodySmallBold)
                                .foregroundStyle(isSelected ? .white : GravityColors.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, GravitySpacing.space12)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(
                            isSelected ? GravityColors.text : GravityColors.bgFillSecondary,
                            in: RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: GravityRadius.r24, style: .continuous)
                                .strokeBorder(Color.black.opacity(isSelected ? 0 : 0.06), lineWidth: 0.5)
                            }
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func priorityIcon(for priority: String) -> GravityIcon {
        switch priority {
        case "Provenance": .checkmarkVerifyFilled
        case "Condition": .sparkle
        case "Original details": .palette
        case "Independent sellers": .profileCircle
        case "Price": .tag
        case "Sustainability": .leafOutline
        default: .sparkleSingle
        }
    }

    private var discoveryQuestion: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Text("How adventurous should her picks be?")
                .gravityTextStyle(GravityTypography.subtitle)

            NariDiscoverySlider(value: $selectedDiscoveryStyle)
        }
    }

    private func answerButton(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .gravityTextStyle(GravityTypography.buttonLarge)
                .foregroundStyle(GravityColors.text)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    GravityColors.bgFillSecondary,
                    in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.96))
    }

    private var addInterestButton: some View {
        Button {
            HapticFeedback.light.fire()
            addsCustomInterest = true
            DispatchQueue.main.async { interestFieldFocused = true }
        } label: {
            Label("Add interest", systemImage: "plus")
                .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(GravityColors.textSecondary)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 40)
                .background(GravityColors.bgFillSecondary, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(
                        Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
                }
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func selectionChip(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(isSelected ? Color.white : GravityColors.textSecondary)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 40)
                .background(
                    isSelected ? GravityColors.text : GravityColors.bgFillSecondary,
                    in: Capsule()
                )
                .overlay {
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.black.opacity(0.05),
                        lineWidth: 0.5
                    )
                }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var allInterestOptions: [String] {
        suggestedInterests + selectedInterests.filter { interest in
            !suggestedInterests.contains {
                $0.caseInsensitiveCompare(interest) == .orderedSame
            }
        }
    }

    private func addCustomInterest() {
        let trimmedInterest = customInterest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInterest.isEmpty,
           !selectedInterests.contains(where: {
               $0.caseInsensitiveCompare(trimmedInterest) == .orderedSame
           }) {
            selectedInterests.append(trimmedInterest)
        }
        customInterest = ""
        addsCustomInterest = false
        interestFieldFocused = false
        HapticFeedback.light.fire()
    }

    private func toggleInterest(_ interest: String) {
        if selectedInterests.contains(interest) {
            selectedInterests.removeAll { $0 == interest }
        } else {
            selectedInterests.append(interest)
        }
    }

    private func togglePriority(_ priority: String) {
        if selectedPriorities.contains(priority) {
            selectedPriorities.removeAll { $0 == priority }
        } else {
            selectedPriorities.append(priority)
        }
    }
}

private struct NariAgeSlider: View {
    @Binding var value: Double

    private let range = 1.0...80.0

    var body: some View {
        NariFillSlider(
            fraction: (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        ) { fraction in
            value = (range.lowerBound + fraction * (range.upperBound - range.lowerBound)).rounded()
        }
        .accessibilityElement()
        .accessibilityLabel("Nari's approximate age")
        .accessibilityValue("\(Int(value)) years old")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(range.upperBound, value + 1)
            case .decrement:
                value = max(range.lowerBound, value - 1)
            @unknown default:
                break
            }
        }
    }
}

private struct NariDiscoverySlider: View {
    @Binding var value: NariProfilePreferences.DiscoveryStyle?

    private let styles = NariProfilePreferences.DiscoveryStyle.allCases

    var body: some View {
        VStack(spacing: GravitySpacing.space10) {
            NariFillSlider(fraction: fraction) { newFraction in
                let index = min(Int(newFraction * Double(styles.count)), styles.count - 1)
                select(styles[max(index, 0)])
            }

            HStack(spacing: 0) {
                ForEach(styles) { style in
                    Button {
                        select(style)
                    } label: {
                        Text(style.title)
                            .gravityTextStyle(value == style
                                ? GravityTypography.bodySmallBold
                                : GravityTypography.bodySmall)
                            .foregroundStyle(value == style
                                ? GravityColors.text
                                : GravityColors.textTertiary)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                    .accessibilityAddTraits(value == style ? .isSelected : [])
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("How far to stretch Nari's taste")
        .accessibilityValue(value?.title ?? "Not set")
        .accessibilityAdjustableAction { direction in
            let currentIndex = value.flatMap { styles.firstIndex(of: $0) }
            switch direction {
            case .increment:
                value = styles[min(styles.count - 1, (currentIndex ?? -1) + 1)]
            case .decrement:
                value = styles[max(0, (currentIndex ?? 1) - 1)]
            @unknown default:
                break
            }
        }
    }

    private var fraction: Double? {
        guard let value,
              let index = styles.firstIndex(of: value),
              !styles.isEmpty else { return nil }
        return Double(index + 1) / Double(styles.count)
    }

    private func select(_ style: NariProfilePreferences.DiscoveryStyle) {
        guard style != value else { return }
        HapticFeedback.selection.fire()
        value = style
    }
}

private struct NariFillSlider: View {
    let fraction: Double?
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                    .fill(GravityColors.bgFillSecondary)

                if let fraction {
                    let clampedFraction = min(max(fraction, 0), 1)
                    let fillWidth = max(12, proxy.size.width * clampedFraction)

                    RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                        .fill(GravityColors.text)
                        .frame(width: fillWidth)

                    if fillWidth < proxy.size.width - 4 {
                        Rectangle()
                            .fill(GravityColors.bg)
                            .frame(width: 4)
                            .offset(x: fillWidth)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let position = min(max(gesture.location.x / proxy.size.width, 0), 1)
                        onChange(position)
                    }
            )
        }
        .frame(height: 32)
    }
}

private struct NariPersonaArtwork: View {
    let persona: NariProfilePreferences.Persona
    let products: [ResolvedStoryProduct]

    private var artworkProducts: [ResolvedStoryProduct] {
        guard !products.isEmpty else { return [] }
        let personaIndex = NariProfilePreferences.Persona.allCases.firstIndex(of: persona) ?? 0
        return [
            products[(personaIndex * 2) % products.count],
            products[(personaIndex * 2 + 1) % products.count],
        ]
    }

    var body: some View {
        ZStack {
            if artworkProducts.isEmpty {
                Image(systemName: persona.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(GravityColors.textSecondary)
            } else {
                personaProduct(artworkProducts[0])
                    .rotationEffect(.degrees(-5))
                    .offset(x: -15, y: 8)

                personaProduct(artworkProducts[1])
                    .rotationEffect(.degrees(6))
                    .offset(x: 16, y: -7)
            }
        }
    }

    private func personaProduct(_ item: ResolvedStoryProduct) -> some View {
        FollowingRemoteImage(urlString: item.product.imageURL)
            .frame(width: 62, height: 72)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                    .strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
    }
}

struct NariBirthdayEditor: View {
    @Bindable var profile: NariProfilePreferences
    var prefillsExistingBirthday = true
    var closeAction: (() -> Void)? = nil
    var onBirthdaySaved: (Date) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var month = ""
    @State private var day = ""
    @State private var year = ""
    @State private var didLoadBirthday = false

    private var parsedBirthday: Date? {
        guard let monthValue = Int(month),
              let dayValue = Int(day) else { return nil }

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let hasYear = !year.isEmpty
        let yearValue: Int
        if hasYear {
            guard year.count == 4,
                  let suppliedYear = Int(year),
                  (currentYear - 120)...currentYear ~= suppliedYear else { return nil }
            yearValue = suppliedYear
        } else {
            // A leap year keeps every valid recurring month/day representable.
            // `birthdayYearKnown` prevents this storage value from becoming an
            // inferred age or appearing in the UI.
            yearValue = 2000
        }

        var components = DateComponents()
        components.calendar = calendar
        components.year = yearValue
        components.month = monthValue
        components.day = dayValue
        components.hour = 12
        guard let date = calendar.date(from: components),
              !hasYear || date <= Date() else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == yearValue,
              resolved.month == monthValue,
              resolved.day == dayValue else { return nil }
        return date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            ZStack {
                Text("Add Nari’s birthday")
                    .gravityTextStyle(GravityTypography.subtitle)
                    .foregroundStyle(GravityColors.text)

                HStack {
                    Button(action: close) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(GravityColors.text)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.94))
                    .accessibilityLabel("Back")

                    Spacer()

                    Button("Save") {
                        saveBirthday()
                    }
                    .gravityTextStyle(GravityTypography.bodySmallBold)
                    .foregroundStyle(
                        parsedBirthday == nil
                            ? GravityColors.textPlaceholder
                            : GravityColors.text
                    )
                    .disabled(parsedBirthday == nil)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 24)

            NariBirthdayFields(
                month: $month,
                day: $day,
                year: $year
            )
            .frame(height: 50)
        }
        .padding(.horizontal, GravitySpacing.space20)
        .padding(.top, GravitySpacing.space20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.ignoresSafeArea())
        .onAppear {
            guard !didLoadBirthday else { return }
            didLoadBirthday = true
            if prefillsExistingBirthday, let birthday = profile.birthday {
                let components = Calendar.current.dateComponents([.year, .month, .day], from: birthday)
                month = components.month.map(String.init) ?? ""
                day = components.day.map(String.init) ?? ""
                year = profile.birthdayYearKnown
                    ? components.year.map(String.init) ?? ""
                    : ""
            }
        }
    }

    private func saveBirthday() {
        guard let birthday = parsedBirthday else { return }
        profile.birthday = birthday
        profile.birthdayYearKnown = !year.isEmpty
        profile.birthdayKnowledge = .known
        HapticFeedback.light.fire()
        onBirthdaySaved(birthday)
        close()
    }

    private func close() {
        if let closeAction {
            closeAction()
        } else {
            dismiss()
        }
    }
}

private struct NariBirthdayFields: UIViewControllerRepresentable {
    @Binding var month: String
    @Binding var day: String
    @Binding var year: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> BirthdayFieldsController {
        let controller = BirthdayFieldsController()
        context.coordinator.controller = controller
        controller.fields.forEach { field in
            field.delegate = context.coordinator
        }
        return controller
    }

    func updateUIViewController(
        _ controller: BirthdayFieldsController,
        context: Context
    ) {
        context.coordinator.parent = self
        let values = [month, day, year]
        for (field, value) in zip(controller.fields, values) where field.text != value {
            field.text = value
        }
        context.coordinator.requestInitialFocusIfNeeded(on: controller)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiViewController: BirthdayFieldsController,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? 0, height: 50)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: NariBirthdayFields
        weak var controller: BirthdayFieldsController?
        private var requestedInitialFocus = false

        init(parent: NariBirthdayFields) {
            self.parent = parent
        }

        func requestInitialFocusIfNeeded(on controller: BirthdayFieldsController) {
            guard !requestedInitialFocus else { return }
            requestedInitialFocus = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak controller] in
                controller?.requestInitialFocus()
            }
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let controller,
                  let current = textField.text,
                  let textRange = Range(range, in: current) else {
                return false
            }

            if string.isEmpty, current.isEmpty,
               let previous = controller.field(before: textField) {
                previous.becomeFirstResponder()
                return false
            }

            let candidate = current.replacingCharacters(in: textRange, with: string)
            let limit = textField.tag == 2 ? 4 : 2
            let sanitized = String(candidate.filter(\.isNumber).prefix(limit))
            textField.text = sanitized
            updateBinding(for: textField.tag, value: sanitized)

            if !string.isEmpty, sanitized.count == limit,
               let next = controller.field(after: textField) {
                next.becomeFirstResponder()
            }
            return false
        }

        private func updateBinding(for tag: Int, value: String) {
            switch tag {
            case 0: parent.month = value
            case 1: parent.day = value
            default: parent.year = value
            }
        }
    }

    final class BirthdayFieldsController: UIViewController, UIGestureRecognizerDelegate {
        let monthField = UITextField()
        let dayField = UITextField()
        let yearField = UITextField()
        private var focusAttemptCount = 0
        private weak var outsideTapRecognizer: UITapGestureRecognizer?

        var fields: [UITextField] { [monthField, dayField, yearField] }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear

            let stack = UIStackView(arrangedSubviews: fields)
            stack.axis = .horizontal
            stack.spacing = GravitySpacing.space8
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)

            for (index, field) in fields.enumerated() {
                configure(field, index: index)
            }
            monthField.accessibilityIdentifier = "nariBirthdayMonth"
            dayField.accessibilityIdentifier = "nariBirthdayDay"
            yearField.accessibilityIdentifier = "nariBirthdayYear"

            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                stack.topAnchor.constraint(equalTo: view.topAnchor),
                stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                monthField.widthAnchor.constraint(equalTo: dayField.widthAnchor),
                yearField.widthAnchor.constraint(equalToConstant: 122),
            ])
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            requestFocus()
            transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
                self?.requestFocus()
            })
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            installOutsideTapRecognizerIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.requestInitialFocus()
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            if let outsideTapRecognizer {
                outsideTapRecognizer.view?.removeGestureRecognizer(outsideTapRecognizer)
            }
        }

        func field(after field: UITextField) -> UITextField? {
            guard let index = fields.firstIndex(of: field), index + 1 < fields.count else {
                return nil
            }
            return fields[index + 1]
        }

        func field(before field: UITextField) -> UITextField? {
            guard let index = fields.firstIndex(of: field), index > 0 else { return nil }
            return fields[index - 1]
        }

        private func configure(_ field: UITextField, index: Int) {
            let placeholder = index == 0 ? "MM" : (index == 1 ? "DD" : "YYYY")
            let font = UIFont(name: GravityFont.semiBold.rawValue, size: 18)
                ?? .systemFont(ofSize: 18, weight: .semibold)
            field.tag = index
            field.keyboardType = .numberPad
            field.textAlignment = .center
            field.textColor = UIColor(GravityColors.text)
            field.tintColor = .systemBlue
            field.font = font
            field.backgroundColor = UIColor(GravityColors.bgFillSecondary)
            field.layer.cornerRadius = GravityRadius.r12
            field.layer.cornerCurve = .continuous
            field.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: font,
                    .foregroundColor: UIColor(GravityColors.textPlaceholder),
                ]
            )
        }

        private func installOutsideTapRecognizerIfNeeded() {
            guard outsideTapRecognizer == nil, let window = view.window else { return }
            let recognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(dismissKeyboard)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            window.addGestureRecognizer(recognizer)
            outsideTapRecognizer = recognizer
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let touchedView = touch.view else { return true }
            return !fields.contains { field in
                touchedView === field || touchedView.isDescendant(of: field)
            }
        }

        @objc private func dismissKeyboard() {
            view.window?.endEditing(true)
        }

        func requestInitialFocus() {
            focusAttemptCount = 0
            requestFocus()
        }

        private func requestFocus() {
            guard view.window != nil else {
                guard focusAttemptCount < 30 else { return }
                focusAttemptCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                    self?.requestFocus()
                }
                return
            }
            if monthField.becomeFirstResponder() {
                monthField.reloadInputViews()
            }
        }
    }
}

private struct NariFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.enumerated().reduce(CGFloat.zero) { partial, element in
            let rowHeight = element.element.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return partial + rowHeight + (element.offset == rows.count - 1 ? 0 : spacing)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    proposal: .unspecified
                )
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth,
               !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

private struct NariGiftGuideCard: View {
    let products: [ResolvedStoryProduct]
    let subtitle: String
    let isRefreshing: Bool
    let namespace: Namespace.ID
    let openGuide: () -> Void

    var body: some View {
        Button(action: openGuide) {
            VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                HStack(alignment: .top, spacing: GravitySpacing.space8) {
                    VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                        Text("Holiday picks for Nari")
                            .font(GravityFont.bold.fixedFont(size: 22))
                            .tracking(GravityLetterSpacing.tighter)
                            .foregroundColor(.white)
                        Text(subtitle)
                            .gravityTextStyle(GravityTypography.bodyLarge)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    FeedForwardDisclosure(
                        size: 36,
                        surface: .black.opacity(0.10),
                        glassTint: .black.opacity(0.10)
                    )
                }
                .padding(.horizontal, GravitySpacing.space20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: GravitySpacing.space8) {
                        if isRefreshing {
                            ForEach(0..<3, id: \.self) { _ in
                                NariRecommendationProductSkeleton(
                                    width: 148,
                                    fill: .white.opacity(0.22),
                                    showsDetails: false
                                )
                            }
                        } else {
                            ForEach(products.prefix(6)) { item in
                                ProductCard(
                                    image: nil,
                                    imageURL: item.product.imageURL,
                                    priceBadge: formatPrice(item.product.price),
                                    showFavoriteButton: true,
                                    usesImageShadow: false
                                )
                                .frame(width: 148)
                                .allowsHitTesting(false)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, GravitySpacing.space20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .frame(height: 148)
                .animation(.easeOut(duration: 0.20), value: isRefreshing)
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: NariDestinationCatalog.giftSurfaceHex), location: 0),
                        .init(color: Color(hex: "#914F73"), location: 0.52),
                        .init(color: Color(hex: "#D88EAE"), location: 1),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                // Snapshot only the lightweight card surface for the shared
                // zoom. Product tiles remain live instead of being flattened
                // synchronously on the tap frame.
                .matchedTransitionSource(id: "nari-gift-guide", in: namespace)
            }
            .contentShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .accessibilityLabel("Open gift ideas for her")
    }
}

private struct NariArchiveEditorialCard: View {
    let namespace: Namespace.ID
    let openEdit: () -> Void

    var body: some View {
        Button(action: openEdit) {
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 620)
                    .overlay {
                        FollowingRemoteImage(urlString: NariDestinationCatalog.heroImageURL)
                    }
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.04), .black.opacity(0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    Text("THE EDIT")
                        .font(GravityFont.semiBold.fixedFont(size: 11))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.68))
                    HStack(alignment: .center, spacing: GravitySpacing.space12) {
                        Text("The Westwood archive")
                            .font(GravityFont.bold.fixedFont(size: 30))
                            .tracking(GravityLetterSpacing.tighter)
                            .layoutPriority(1)

                        Spacer(minLength: 0)

                        FeedForwardDisclosure(
                            size: 36,
                            surface: .black.opacity(0.10),
                            glassTint: .black.opacity(0.10)
                        )
                        .fixedSize()
                    }
                    Text("Rare Westwood pieces, sourced across independent shops.")
                        .font(GravityFont.regular.fixedFont(size: 14))
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space24)
                .padding(.bottom, 28)
            }
            .frame(height: 620)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(PressScaleButtonStyle(scale: 0.985))
        .matchedTransitionSource(id: "nari-westwood-edit", in: namespace)
        .accessibilityLabel("Explore the Vivienne Westwood archive edit")
    }
}

private struct NariProductRail: View {
    let title: String
    let subtitle: String
    let products: [ResolvedStoryProduct]
    let isRefreshing: Bool
    let openProduct: (ResolvedStoryProduct) -> Void

    var body: some View {
        if !products.isEmpty {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                    Text(title)
                        .font(GravityFont.bold.fixedFont(size: 22))
                        .tracking(GravityLetterSpacing.tighter)
                        .foregroundStyle(GravityColors.text)
                    Text(subtitle)
                        .font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(GravityColors.textSecondary)
                }
                .padding(.horizontal, GravitySpacing.space12)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                        if isRefreshing {
                            ForEach(0..<4, id: \.self) { _ in
                                NariRecommendationProductSkeleton(
                                    width: 144,
                                    fill: GravityColors.bgFillSecondary,
                                    showsDetails: true
                                )
                            }
                        } else {
                            ForEach(products) { item in
                                Button {
                                    openProduct(item)
                                } label: {
                                    ProductCard(
                                        image: nil,
                                        imageURL: item.product.imageURL,
                                        merchantName: item.merchant.displayName,
                                        productName: item.product.title,
                                        price: formatPrice(item.product.price),
                                        showFavoriteButton: true,
                                        usesImageShadow: false
                                    )
                                    .frame(width: 144)
                                }
                                .buttonStyle(PressScaleButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, GravitySpacing.space12)
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .frame(height: 228)
                .animation(.easeOut(duration: 0.20), value: isRefreshing)
            }
        }
    }
}

private struct NariRecommendationProductSkeleton: View {
    let width: CGFloat
    let fill: Color
    let showsDetails: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                .fill(fill)
                .frame(width: width, height: width)

            if showsDetails {
                RoundedRectangle(cornerRadius: GravityRadius.r4)
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: width * 0.58, height: 10)
                RoundedRectangle(cornerRadius: GravityRadius.r4)
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: width * 0.82, height: 10)
                RoundedRectangle(cornerRadius: GravityRadius.r4)
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: width * 0.40, height: 10)
            }
        }
        .frame(width: width, alignment: .leading)
        .shimmer(active: !reduceMotion)
        .accessibilityHidden(true)
    }
}

private struct NariShoppingDetailsEditor: View {
    @Bindable var profile: NariProfilePreferences

    @Environment(\.dismiss) private var dismiss
    @State private var relationship: String
    @State private var clothingSize: String
    @State private var pantsSize: String
    @State private var dressSize: String
    @State private var shoeSize: String
    @State private var fitNotes: String
    @FocusState private var fitNotesFocused: Bool

    private let relationships = ["Partner", "Spouse", "Friend", "Family", "Coworker", "Other"]
    private let clothingSizes = ["XXS", "XS", "S", "M", "L", "XL", "XXL"]
    private let numericSizes = ["00", "0", "2", "4", "6", "8", "10", "12", "14", "16", "18", "20"]
    private let shoeSizes = stride(from: 5.0, through: 12.0, by: 0.5).map { size in
        size.rounded() == size ? "US \(Int(size))" : "US \(size.formatted())"
    }

    init(profile: NariProfilePreferences) {
        self.profile = profile
        _relationship = State(initialValue: profile.relationship)
        _clothingSize = State(initialValue: profile.clothingSize)
        _pantsSize = State(initialValue: profile.pantsSize)
        _dressSize = State(initialValue: profile.dressSize)
        _shoeSize = State(initialValue: profile.shoeSize)
        _fitNotes = State(initialValue: profile.fitNotes)
    }

    private var normalizedFitNotes: String {
        fitNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.18))
                .frame(width: 36, height: 5)
                .padding(.top, GravitySpacing.space10)
                .padding(.bottom, GravitySpacing.space16)

            VStack(spacing: GravitySpacing.space6) {
                Image("nari-avatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay {
                        Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    }

                Text("Nari")
                    .font(GravityFont.bold.fixedFont(size: 28))
                    .tracking(GravityLetterSpacing.tighter)
                    .foregroundStyle(GravityColors.text)
            }
            .padding(.bottom, GravitySpacing.space20)

            ScrollView {
                VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                    detailMenu(
                        title: "Relationship",
                        value: relationship,
                        options: relationships,
                        allowsClearing: false,
                        onSelect: { relationship = $0 }
                    )

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: GravitySpacing.space8),
                            GridItem(.flexible(), spacing: GravitySpacing.space8),
                        ],
                        spacing: GravitySpacing.space8
                    ) {
                        detailMenu(
                            title: "Tops",
                            value: clothingSize,
                            options: clothingSizes,
                            onSelect: { clothingSize = $0 }
                        )
                        detailMenu(
                            title: "Pants",
                            value: pantsSize,
                            options: numericSizes,
                            onSelect: { pantsSize = $0 }
                        )
                        detailMenu(
                            title: "Dresses",
                            value: dressSize,
                            options: numericSizes,
                            onSelect: { dressSize = $0 }
                        )
                        detailMenu(
                            title: "Shoes",
                            value: shoeSize,
                            options: shoeSizes,
                            onSelect: { shoeSize = $0 }
                        )
                    }

                    VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                        Text("Fit notes")
                            .gravityTextStyle(GravityTypography.bodyTitleSmall)
                            .foregroundStyle(GravityColors.text)

                        TextField(
                            "Favorite fits, brands, or anything useful",
                            text: $fitNotes,
                            axis: .vertical
                        )
                        .gravityTextStyle(GravityTypography.bodySmall)
                        .foregroundStyle(GravityColors.text)
                        .focused($fitNotesFocused)
                        .lineLimit(2...4)
                        .padding(.horizontal, GravitySpacing.space12)
                        .padding(.vertical, GravitySpacing.space12)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .background(
                            GravityColors.bgFillSecondary,
                            in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                        )
                        .simultaneousGesture(
                            TapGesture().onEnded { fitNotesFocused = true }
                        )
                    }
                }
                .padding(.horizontal, GravitySpacing.space20)
                .padding(.bottom, GravitySpacing.space20)
            }
            .scrollDismissesKeyboard(.interactively)

            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)

            HStack(spacing: GravitySpacing.space12) {
                Button {
                    HapticFeedback.light.fire()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .gravityTextStyle(GravityTypography.buttonLarge)
                        .foregroundStyle(GravityColors.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            GravityColors.bgFillSecondary,
                            in: Capsule()
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.985))

                Button {
                    HapticFeedback.light.fire()
                    profile.relationship = relationship
                    profile.clothingSize = clothingSize
                    profile.pantsSize = pantsSize
                    profile.dressSize = dressSize
                    profile.shoeSize = shoeSize
                    profile.fitNotes = normalizedFitNotes
                    dismiss()
                } label: {
                    Text("Save")
                        .gravityTextStyle(GravityTypography.buttonLarge)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            GravityColors.text,
                            in: Capsule()
                        )
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.985))
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.vertical, GravitySpacing.space16)
        }
        .background(Color.white.opacity(0.92))
        .onAppear {
            // Opening shopping details should not imply text entry. The keyboard
            // belongs to the explicit Fit notes interaction below.
            fitNotesFocused = false
        }
        .task {
#if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("-focusNariFitNotes") else { return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            fitNotesFocused = true
#endif
        }
    }

    private func detailMenu(
        title: String,
        value: String,
        options: [String],
        allowsClearing: Bool = true,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            if allowsClearing {
                Button("Not set") { onSelect("") }
                Divider()
            }
            ForEach(options, id: \.self) { option in
                Button {
                    HapticFeedback.selection.fire()
                    onSelect(option)
                } label: {
                    if option == value {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            HStack(alignment: .top, spacing: GravitySpacing.space8) {
                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    Text(title)
                        .gravityTextStyle(GravityTypography.captionBold)
                        .foregroundStyle(GravityColors.textTertiary)

                    Text(value.isEmpty ? "Select" : value)
                        .gravityTextStyle(GravityTypography.bodyTitleLarge)
                        .foregroundStyle(value.isEmpty ? GravityColors.textPlaceholder : GravityColors.text)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(GravityColors.textTertiary)
                    .padding(.top, GravitySpacing.space2)
            }
            .padding(.horizontal, GravitySpacing.space12)
            .frame(maxWidth: .infinity, minHeight: 68, maxHeight: 68, alignment: .leading)
            .background(
                GravityColors.bgFillSecondary,
                in: RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
            )
        }
        .menuIndicator(.hidden)
        .buttonStyle(PressScaleButtonStyle(scale: 0.98))
    }
}

#Preview("Nari destination") {
    @Previewable @Namespace var namespace
    let merchants = LocalMerchantService.mergeMerchants([
        SampleMerchant.previews,
        HypothesisShelfCatalog.merchants,
        BuyerPersonalizationCatalog.merchants,
    ])
    let giftProducts = BuyerPersonalizationCatalog.stories
        .first { $0.id == HypothesisShelfCatalog.giftGuideStoryID }?
        .resolvedProducts(from: merchants) ?? []

    NariDestinationFeed(
        giftProducts: giftProducts,
        archiveProducts: NariDestinationCatalog.archiveProducts(from: merchants),
        topInset: 48,
        namespace: namespace
    )
    .environment(NavigationCoordinator())
}

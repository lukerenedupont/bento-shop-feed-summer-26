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
                Group {
                    if let logo = merchant.bestWordmarkURL ?? merchant.bestLogoURL,
                       let url = URL(string: logo) {
                        CachedAsyncImage(url: url) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFit()
                            } else {
                                Text(merchant.displayName)
                                    .font(GravityFont.bold.fixedFont(size: 18))
                            }
                        }
                        .frame(width: 112, height: 34, alignment: .leading)
                    } else {
                        Text(merchant.displayName)
                            .font(GravityFont.bold.fixedFont(size: 18))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(.white)

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
            if let normalizedURLString, let cached = ImageCache.shared.image(for: normalizedURLString) {
                cached.resizable().scaledToFill()
            } else if let normalizedURLString, let url = URL(string: normalizedURLString) {
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

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selectedBand: DealFilterBand = .all

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
                dealFilterTrain

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
    }

    private var dealFilterTrain: some View {
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
    }

    private func reward(for merchant: SampleMerchant) -> Int {
        let stableSeed = merchant.id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return [10, 20, 30][stableSeed % 3]
    }

    private func openProduct(_ merchant: SampleMerchant, _ product: SampleMerchant.Product) {
        coordinator.pushRoute(.product(merchantId: merchant.id, productId: product.id))
    }
}

private enum DealFilterBand: String, CaseIterable, Identifiable {
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

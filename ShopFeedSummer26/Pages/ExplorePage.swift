import SwiftUI

/// Explore page matching the updated Figma "Explore" frame (618:50889).
///
/// Sections top to bottom:
/// 1. Hero promo carousel (kept from previous design)
/// 2. Category tiles grid (2×3 colored cards) + category chips row
/// 3. Product rail sections (generic category-based rails with SectionHeader + horizontal ProductCard scroll)
struct ExplorePage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @ObservedObject private var merchantService = RemoteMerchantService.shared

    @Namespace private var heroNamespace

    private var merchants: [SampleMerchant] { merchantService.merchants }
    private let contentPadding: CGFloat = GravitySpacing.screenMargin

    // MARK: - Category Tile Data

    /// Category tiles matching Figma: label + background color + category key for matching merchants.
    private struct CategoryTileData {
        let label: String
        let color: Color
        /// Matches against SampleMerchant.productCategory (from GMV data).
        let categoryKeys: [String]
    }

    private let categoryTiles: [CategoryTileData] = [
        .init(label: "Beauty", color: Color(hex: 0xFF446D), categoryKeys: ["Health & Beauty"]),
        .init(label: "Fashion", color: Color(hex: 0x9EA6AC), categoryKeys: ["Apparel & Accessories", "Luggage & Bags"]),
        .init(label: "Home", color: Color(hex: 0xCE5F01), categoryKeys: ["Home & Garden"]),
        .init(label: "Entertainment", color: Color(hex: 0x003988), categoryKeys: ["Arts & Entertainment", "Toys & Games", "Media"]),
        .init(label: "Electronics", color: Color(hex: 0x251875), categoryKeys: ["Electronics"]),
        .init(label: "Food & Drink", color: Color(hex: 0x9DB798), categoryKeys: ["Food, Beverages & Tobacco"]),
    ]

    /// Find the best merchant for a category tile based on productCategory.
    private func merchantForCategory(_ tile: CategoryTileData) -> SampleMerchant? {
        merchants.first { merchant in
            guard let cat = merchant.productCategory else { return false }
            return tile.categoryKeys.contains(cat)
        }
    }

    // MARK: - Category Chip Data

    /// Category chips below the tiles (Figma: Accessories, Food & drinks, etc.)
    private var categoryChipLabels: [String] {
        Array(Set(merchants.flatMap { $0.collections.map(\.name) })).sorted().prefix(8).map { $0 }
    }

    // MARK: - Product Rail Sections

    /// Each product rail "Box" section from the Figma.
    private struct ProductRailSection: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String?
        let showChevron: Bool
    }

    /// Build product rail sections dynamically from available merchant categories.
    private var productRailSections: [ProductRailSection] {
        var sections: [ProductRailSection] = []

        // Create sections based on categories we actually have merchants for
        let categoryLabels: [(keys: [String], title: String, subtitle: String?)] = [
            (["Apparel & Accessories"], "Trending in Fashion", nil),
            (["Health & Beauty"], "What's new in Beauty", nil),
            (["Home & Garden"], "Home essentials", "Trustworthy staples that people re-buy"),
            (["Arts & Entertainment", "Toys & Games"], "Fun finds", nil),
        ]

        for cat in categoryLabels {
            let hasProducts = merchants.contains { m in
                guard let pc = m.productCategory else { return false }
                return cat.keys.contains(pc) && !m.products.isEmpty
            }
            if hasProducts {
                sections.append(.init(title: cat.title, subtitle: cat.subtitle, showChevron: true))
            }
        }

        // Always have at least 2 sections
        if sections.isEmpty {
            sections = [
                .init(title: "Popular right now", subtitle: nil, showChevron: true),
                .init(title: "Top picks", subtitle: "Trustworthy staples that people re-buy", showChevron: true),
            ]
        }

        return sections
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: GravitySpacing.space24) {
                if !merchants.isEmpty {
                    heroCarousel
                }
                categoryTilesSection
                ForEach(Array(productRailSections.enumerated()), id: \.element.id) { index, section in
                    productRailBox(section: section, productOffset: index * 3)
                }
            }
            .padding(.bottom, PurlTune.value("Pages/ExplorePage.swift:padding:_:108:31", default: 120))
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, offset in
            coordinator.updateScrollOffset(offset)
        }
        .safeAreaBar(edge: .top) {
            HStack(spacing: GravitySpacing.space8) {
                Text("Explore")
                    .gravityTextStyle(GravityTypography.header)
                    .foregroundStyle(PurlTune.token("Pages/ExplorePage.swift:foregroundStyle:_:119:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                Spacer()
            }
            .frame(minHeight: PurlTune.value("Pages/ExplorePage.swift:frame:minHeight:122:31", default: 44))
            .padding(.horizontal, PurlTune.token("Pages/ExplorePage.swift:padding:_:123:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.token("Pages/ExplorePage.swift:padding:_:124:31", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .purlInjectable()
    }

    // MARK: - 1. Hero Promo Carousel (kept from previous design)

    private var heroCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                ForEach(Array(merchants.prefix(4).enumerated()), id: \.element.id) { _, merchant in
                    heroPromoCard(merchant)
                }
            }
            .padding(.horizontal, contentPadding)
            .padding(.vertical, PurlTune.token("Pages/ExplorePage.swift:padding:_:157:33", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        }
        .scrollClipDisabled()
    }

    private func heroPromoCard(_ merchant: SampleMerchant) -> some View {
        ZStack(alignment: .bottomLeading) {
            MerchantCoverImage(merchant: merchant)
                .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:165:31", default: 361), height: PurlTune.value("Pages/ExplorePage.swift:frame:height:165:115", default: 203))
                .clipped()

            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.4),
                            .init(color: .black.opacity(PurlTune.value("Pages/ExplorePage.swift:opacity:_:173:57", default: 0.5)), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(Color.black.opacity(PurlTune.value("Pages/ExplorePage.swift:opacity:_:179:46", default: 0.2)))

            HStack(alignment: .bottom, spacing: GravitySpacing.space8) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(merchant.name)
                        .gravityTextStyle(GravityTypography.sectionTitle)
                        .foregroundStyle(.white)

                    Text(merchant.description.isEmpty ? "Live store from Shop Server" : merchant.description)
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(.white.opacity(PurlTune.value("Pages/ExplorePage.swift:opacity:_:189:57", default: 0.75)))
                        .lineLimit(2)
                }
                .frame(maxWidth: PurlTune.value("Pages/ExplorePage.swift:frame:maxWidth:192:34", default: 267), alignment: .leading)

                Spacer()

                Circle()
                    .fill(.white.opacity(PurlTune.value("Pages/ExplorePage.swift:opacity:_:197:42", default: 0.2)))
                    .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:198:35", default: 32), height: PurlTune.value("Pages/ExplorePage.swift:frame:height:198:118", default: 32))
                    .overlay(
                        GravityIcon.arrowRight.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:203:43", default: 16), height: PurlTune.value("Pages/ExplorePage.swift:frame:height:203:126", default: 16))
                            .foregroundStyle(.white)
                    )
            }
            .padding(PurlTune.token("Pages/ExplorePage.swift:padding:_:207:22", default: GravitySpacing.space20, options: GravitySpacing.purlTuneOptions))
        }
        .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:209:23", default: 361), height: PurlTune.value("Pages/ExplorePage.swift:frame:height:209:107", default: 203))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .gravityShadow(GravityShadows.medium)
    }

    // MARK: - 2. Category Tiles Section

    /// Figma: 2-column grid of colored CategoryTile cards (177×133) + category chips row below.
    /// Vertical layout, gap 12, px 16.
    private var categoryTilesSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // 2×3 grid of category tiles
            let columns = [
                GridItem(.flexible(), spacing: GravitySpacing.space8),
                GridItem(.flexible(), spacing: GravitySpacing.space8),
            ]

            if !categoryChipLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(categoryChipLabels, id: \.self) { label in
                            Text(label)
                                .gravityTextStyle(GravityTypography.captionMedium)
                                .foregroundStyle(PurlTune.token("Pages/ExplorePage.swift:foregroundStyle:_:232:50", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                                .padding(.horizontal, PurlTune.token("Pages/ExplorePage.swift:padding:_:233:55", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                                .padding(.vertical, PurlTune.token("Pages/ExplorePage.swift:padding:_:234:53", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                                .background(GravityColors.bgFillSecondary, in: Capsule())
                        }
                    }
                    .padding(.horizontal, contentPadding)
                }
            }

            LazyVGrid(columns: columns, spacing: GravitySpacing.space8) {
                ForEach(Array(categoryTiles.enumerated()), id: \.element.label) { index, tile in
                    if merchants.isEmpty {
                        EmptyView()
                    } else {
                    let merchant = merchantForCategory(tile) ?? merchants[index % merchants.count]
                    let thumbURLs = merchant.featuredImageURLs.prefix(2).map { $0 }

                    CategoryTile(
                        label: tile.label,
                        backgroundColor: tile.color,
                        thumbnailImages: [],
                        thumbnailURLs: Array(thumbURLs),
                        onTap: {
                            coordinator.pushRoute(.store(merchantId: merchant.id))
                        }
                    )
                    .matchedTransitionSource(id: merchant.id, in: heroNamespace)
                    }
                }
            }
            .padding(.horizontal, contentPadding)
        }
    }

    // MARK: - 3. Product Rail Box Sections

    /// Figma "Box": SectionHeader (subtitle + chevron pill) + horizontal ProductCard rail.
    /// Each box is VERTICAL layout, gap 12, pl 16.
    /// ProductCards are 173px wide with full metadata.
    private func productRailBox(section: ProductRailSection, productOffset: Int) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // Section header
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                sectionHeader(title: section.title, showChevron: section.showChevron)

                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .gravityTextStyle(GravityTypography.bodySmall)
                        .foregroundStyle(PurlTune.token("Pages/ExplorePage.swift:foregroundStyle:_:281:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                        .padding(.horizontal, contentPadding)
                }
            }

            // Horizontal product card rail
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(sectionProducts(offset: productOffset).prefix(8), id: \.product.id) { item in
                        NavigationLink(value: HomeRoute.product(merchantId: item.merchant.id, productId: item.product.id)) {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.name,
                                productName: item.product.title,
                                rating: item.merchant.rating,
                                ratingCount: item.merchant.totalRatings,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true,
                                merchantLogoImage: nil,
                                merchantLogoURL: item.merchant.bestLogoURL
                            )
                            .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:303:43", default: 173))
                            .matchedTransitionSource(id: item.product.id, in: heroNamespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, contentPadding)
                .padding(.vertical, PurlTune.token("Pages/ExplorePage.swift:padding:_:310:37", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Section Header

    /// Gravity: sectionTitle (20pt semibold) — heads a list/grid/rail of grouped items.
    /// Optional chevron pill (bgFillSecondary bg, r24).
    private func sectionHeader(title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: GravitySpacing.space4) {
            Text(title)
                .gravityTextStyle(GravityTypography.sectionTitle)
                .foregroundStyle(PurlTune.token("Pages/ExplorePage.swift:foregroundStyle:_:324:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))

            if showChevron {
                GravityIcon.boldRightChevron.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/ExplorePage.swift:frame:width:330:35", default: 16), height: PurlTune.value("Pages/ExplorePage.swift:frame:height:330:118", default: 16))
                    .foregroundStyle(PurlTune.token("Pages/ExplorePage.swift:foregroundStyle:_:331:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .padding(PurlTune.token("Pages/ExplorePage.swift:padding:_:332:30", default: GravitySpacing.space2, options: GravitySpacing.purlTuneOptions))
                    .background(GravityColors.bgFillSecondary, in: RoundedRectangle(cornerRadius: 24))
            }

            Spacer()
        }
        .padding(.horizontal, contentPadding)
    }

    // MARK: - Data Helpers

    private struct ProductItem {
        let product: SampleMerchant.Product
        let merchant: SampleMerchant
    }

    private var allProducts: [ProductItem] {
        merchants.flatMap { merchant in
            merchant.products.prefix(3).map { ProductItem(product: $0, merchant: merchant) }
        }
    }

    /// Returns a slice of products for a given section, cycling through the pool.
    private func sectionProducts(offset: Int) -> [ProductItem] {
        guard !allProducts.isEmpty else { return [] }
        let count = allProducts.count
        let start = offset % count
        // Return up to 8 products, wrapping around
        return (0..<8).map { i in
            allProducts[(start + i) % count]
        }
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExplorePage()
    }
    .environment(NavigationCoordinator())
}

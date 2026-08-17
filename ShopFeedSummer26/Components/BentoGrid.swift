import SwiftUI

/// Cell sizes in the bento grammar. Unsized compartments are resolved from
/// shopper signal strength (see `BentoCompartment.resolveSize`).
enum BentoCellSize: String {
    /// Full width, tall. The box's anchor — cart-signal or filmed content.
    case hero
    /// Full width, short banner.
    case wide
    /// Half width. The default compartment.
    case standard
}

/// One compartment of a bento: a stated role, a visual surface, and a
/// destination. "Every compartment has purpose, every product has context."
struct BentoCompartment: Identifiable {
    enum Surface {
        case product(ResolvedStoryProduct)
        case merchant(SampleMerchant)
        case story(FeedStory, hero: ResolvedStoryProduct?)
        /// Tall brand card: cover as the whole surface, avatar + name +
        /// rating header, two shoppable product chips floating at the base.
        case merchantSpotlight(SampleMerchant, [ResolvedStoryProduct])
        /// Circular shop avatars floating chrome-free on the topic surface —
        /// 2×2 in a square cell, 2×3 in a tall one. Each disc opens a store.
        case avatarCluster([SampleMerchant])
    }

    let id: String
    let role: String
    let size: BentoCellSize
    let surface: Surface
    let action: () -> Void

    /// Explicit authored size wins; otherwise real data decides: an item in
    /// your cart anchors the box, filmed content earns a wide cell, and
    /// everything else packs in at standard.
    static func resolveSize(explicit: String?, signal: ShopperSignals.SignalStrength, hasFilm: Bool) -> BentoCellSize {
        if let explicit, let size = BentoCellSize(rawValue: explicit) { return size }
        if signal == .cart { return .hero }
        if hasFilm || signal >= .owned { return .wide }
        return .standard
    }
}

/// Lays compartments into a two-column packed box. Hero and wide cells span
/// the full width. Standard cells never fall into a plain grid: runs of
/// squares are clustered into tall-anchored trios (one tall cell beside two
/// stacked squares, alternating sides), leftover pairs sit side by side, and
/// a lone orphan is promoted to a full-width banner. Layout stays
/// deterministic from the compartment order — curation lives in data.
struct BentoGrid: View {
    let compartments: [BentoCompartment]
    let containerWidth: CGFloat

    private let spacing: CGFloat = GravitySpacing.space8
    private var columnWidth: CGFloat { (containerWidth - spacing) / 2 }
    /// Tall cells span exactly two square rows, so the cluster stays flush.
    private var tallHeight: CGFloat { columnWidth * 2 + spacing }

    private func height(for size: BentoCellSize) -> CGFloat {
        switch size {
        case .hero: return 420
        case .wide: return 180
        // Paired cells are 1:1 — same square grammar as ProductCard tiles.
        case .standard: return columnWidth
        }
    }

    /// A resolved layout row — the rhythm grammar of the box.
    private enum LayoutRow {
        /// Hero or wide cell spanning the container.
        case full(BentoCompartment)
        /// An orphan standard promoted to a full-width banner.
        case banner(BentoCompartment)
        /// Two squares side by side.
        case pair(BentoCompartment, BentoCompartment)
        /// One tall cell beside two stacked squares.
        case trio(tall: BentoCompartment, top: BentoCompartment, bottom: BentoCompartment, tallLeading: Bool)
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Array(layoutRows.enumerated()), id: \.offset) { _, row in
                rowView(row)
            }
        }
        .frame(width: containerWidth)
    }

    @ViewBuilder
    private func rowView(_ row: LayoutRow) -> some View {
        switch row {
        case .full(let compartment):
            BentoCompartmentCard(compartment: compartment)
                .frame(width: containerWidth, height: height(for: compartment.size))
        case .banner(let compartment):
            BentoCompartmentCard(compartment: compartment)
                .frame(width: containerWidth, height: height(for: .wide))
        case .pair(let leading, let trailing):
            HStack(spacing: spacing) {
                BentoCompartmentCard(compartment: leading)
                    .frame(width: columnWidth, height: columnWidth)
                BentoCompartmentCard(compartment: trailing)
                    .frame(width: columnWidth, height: columnWidth)
            }
        case .trio(let tall, let top, let bottom, let tallLeading):
            HStack(spacing: spacing) {
                if tallLeading { tallCell(tall) }
                VStack(spacing: spacing) {
                    BentoCompartmentCard(compartment: top)
                        .frame(width: columnWidth, height: columnWidth)
                    BentoCompartmentCard(compartment: bottom)
                        .frame(width: columnWidth, height: columnWidth)
                }
                if !tallLeading { tallCell(tall) }
            }
        }
    }

    private func tallCell(_ compartment: BentoCompartment) -> some View {
        BentoCompartmentCard(compartment: compartment)
            .frame(width: columnWidth, height: tallHeight)
    }

    /// Full-width cells flush the pending run of standards; each run is
    /// clustered so something always breaks the grid: trios first (sides
    /// alternating box-wide), a final pair if two remain, a banner if one.
    private var layoutRows: [LayoutRow] {
        var rows: [LayoutRow] = []
        var run: [BentoCompartment] = []
        var trioCount = 0

        func flushRun() {
            while !run.isEmpty {
                // Give longer standard runs an editorial breath: promote one
                // compartment to a full-width media banner before packing the
                // remaining products back into the tighter bento rhythm.
                if run.count >= 4 {
                    rows.append(.banner(run.removeFirst()))
                } else if run.count == 1 {
                    rows.append(.banner(run.removeFirst()))
                } else if run.count == 2 {
                    rows.append(.pair(run.removeFirst(), run.removeFirst()))
                } else {
                    let tall = run.removeFirst()
                    let top = run.removeFirst()
                    let bottom = run.removeFirst()
                    rows.append(.trio(tall: tall, top: top, bottom: bottom, tallLeading: trioCount.isMultiple(of: 2)))
                    trioCount += 1
                }
            }
        }

        for compartment in compartments {
            if compartment.size == .standard {
                run.append(compartment)
            } else {
                flushRun()
                rows.append(.full(compartment))
            }
        }
        flushRun()
        return rows
    }
}

/// Topic-page presentation of the bento recipe. The authored roles become
/// distinct horizontal product rails, while the lead and brand moments keep
/// enough height for generated films and lifestyle imagery to breathe.
struct GroupedTopicBento: View {
    let compartments: [BentoCompartment]
    let containerWidth: CGFloat

    private let sectionSpacing: CGFloat = 30
    private let railSpacing: CGFloat = GravitySpacing.space12

    private var lead: BentoCompartment? {
        compartments.first(where: { $0.size == .hero }) ?? compartments.first
    }

    private var remaining: [BentoCompartment] {
        guard let lead else { return compartments }
        return compartments.filter { $0.id != lead.id }
    }

    private var productGroups: [(role: String, items: [BentoCompartment])] {
        var order: [String] = []
        var groups: [String: [BentoCompartment]] = [:]

        for item in remaining {
            guard case .product = item.surface else { continue }
            let role = item.role.isEmpty ? "More to explore" : item.role
            if groups[role] == nil { order.append(role) }
            groups[role, default: []].append(item)
        }

        return order.compactMap { role in
            groups[role].map { (role: role, items: $0) }
        }
    }

    private var editorialItems: [BentoCompartment] {
        remaining.filter {
            if case .product = $0.surface { return false }
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if let lead {
                BentoCompartmentCard(compartment: lead)
                    .frame(width: containerWidth, height: 520)
            }

            ForEach(productGroups, id: \.role) { group in
                if group.items.count == 1, let item = group.items.first {
                    featuredProduct(title: group.role, item: item)
                } else {
                    productRail(title: group.role, items: group.items)
                }
            }

            if !editorialItems.isEmpty {
                editorialRail
            }
        }
        .frame(width: containerWidth, alignment: .leading)
    }

    private func productRail(
        title: String,
        items: [BentoCompartment]
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            railTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: railSpacing) {
                    ForEach(items) { item in
                        BentoCompartmentCard(compartment: item)
                            .frame(width: min(containerWidth * 0.68, 270), height: 360)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func featuredProduct(
        title: String,
        item: BentoCompartment
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            railTitle(title)
            BentoCompartmentCard(compartment: item)
                .frame(width: containerWidth, height: 420)
        }
    }

    private var editorialRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            railTitle("Makers and shops")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: railSpacing) {
                    ForEach(editorialItems) { item in
                        BentoCompartmentCard(compartment: item)
                            .frame(width: min(containerWidth * 0.78, 310), height: 380)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func railTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .bold))
            .tracking(-0.2)
            .foregroundStyle(.white)
    }
}

/// The compartment shell: ambient surface, bottom legibility scrim, and
/// title. Roles stay data-side (sizing + validator contract) — the imagery
/// carries the cell, and dossier films will fill these surfaces as they land.
private struct BentoCompartmentCard: View {
    let compartment: BentoCompartment

    var body: some View {
        // The avatar cluster is chrome-free: no card shell, no scrim, no
        // single destination — the discs themselves are the buttons.
        if case .avatarCluster(let merchants) = compartment.surface {
            BentoAvatarClusterCell(merchants: merchants)
                .accessibilityLabel(compartment.role)
        } else {
            card
        }
    }

    private var card: some View {
        Button(action: compartment.action) {
            ZStack(alignment: .bottomLeading) {
                surface

                // Bottom-only scrim for the title; the top of the cell
                // stays untouched so the asset reads clean. Brand-forward
                // surfaces carry their own identity, so no title either.
                if showsTitle {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.55),
                            .init(color: .black.opacity(0.72), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Text(title)
                        .font(.system(size: compartment.size == .hero ? 22 : 15, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(12)
                }
            }
            // Same price treatment as ProductCard tiles: badge pill in the
            // top-leading corner instead of a subtitle under the title.
            .overlay(alignment: .topLeading) {
                if let price {
                    Text(price)
                        .gravityTextStyle(GravityTypography.badgeBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GravityRadius.max))
                        .environment(\.colorScheme, .dark)
                        .padding(GravitySpacing.space12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("\(compartment.role): \(title)")
    }

    /// Brand-forward surfaces (spotlight, wordmark-style merchant cells)
    /// carry their own identity — the default bottom title would double up.
    private var showsTitle: Bool {
        switch compartment.surface {
        case .merchantSpotlight, .merchant, .avatarCluster: return false
        case .product, .story: return true
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch compartment.surface {
        case .product(let item):
            AmbientProductVideo(product: item.product, merchant: item.merchant)
        case .merchant(let merchant):
            // Wordmark moment (per shopdotcom reference): the cover carries
            // the cell, the wordmark holds the center, rating beneath.
            ZStack {
                Color.clear.overlay { MerchantCoverImage(merchant: merchant) }.clipped()
                RadialGradient(
                    colors: [.black.opacity(0.38), .black.opacity(0.12)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
                VStack(spacing: GravitySpacing.space4) {
                    MerchantWordmarkImage(merchant: merchant, maxHeight: 30, maxWidth: 180)
                    if merchant.totalRatings > 0 {
                        BentoMerchantRatingRow(merchant: merchant)
                    }
                }
            }
        case .merchantSpotlight(let merchant, let products):
            BentoSpotlightSurface(merchant: merchant, products: products)
        case .avatarCluster:
            // Handled chrome-free in `body`; never reaches the card shell.
            Color.clear
        case .story(let story, let hero):
            if let hero, !hero.product.ambientFilmURLs(merchantID: hero.merchant.id).isEmpty {
                AmbientProductVideo(product: hero.product, merchant: hero.merchant)
            } else if let coverImageName = story.coverImageName {
                Color.clear
                    .overlay { Image(coverImageName).resizable().scaledToFill() }
                    .clipped()
            } else if let hero {
                AmbientProductVideo(product: hero.product, merchant: hero.merchant)
            } else {
                Color(hex: story.accentHex)
            }
        }
    }

    private var title: String {
        switch compartment.surface {
        case .product(let item): return item.product.title
        case .merchant(let merchant): return merchant.displayName
        case .merchantSpotlight(let merchant, _): return merchant.displayName
        case .avatarCluster: return compartment.role
        case .story(let story, _): return story.title
        }
    }

    private var price: String? {
        switch compartment.surface {
        case .product(let item): return formatPrice(item.product.price)
        case .merchant, .merchantSpotlight, .avatarCluster, .story: return nil
        }
    }
}

/// "4.6 ★ (194)" — shared rating row for the brand-forward cells.
private struct BentoMerchantRatingRow: View {
    let merchant: SampleMerchant

    var body: some View {
        HStack(spacing: 3) {
            Text(String(format: "%.1f", merchant.rating))
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(.white)
            GravityIcon.starFilled.image
                .resizable().scaledToFit()
                .frame(width: 10, height: 10)
                .foregroundStyle(.white)
            Text("(\(merchant.totalRatings))")
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

/// The tall brand card surface: merchant cover, identity header, and two
/// floating product chips. Chips only render when the cell is taller than
/// wide (the trio's tall anchor) — in a square there's no room for them.
private struct BentoSpotlightSurface: View {
    let merchant: SampleMerchant
    let products: [ResolvedStoryProduct]

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .overlay { MerchantCoverImage(merchant: merchant) }
                    .clipped()
                // Soft top scrim keeps the identity row legible on any cover.
                LinearGradient(
                    colors: [.black.opacity(0.45), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .overlay(alignment: .topLeading) {
                HStack(spacing: GravitySpacing.space8) {
                    MerchantLogoImage(merchant: merchant, size: 36)
                        .background(Circle().fill(.white))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(merchant.displayName)
                            .gravityTextStyle(GravityTypography.captionBold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if merchant.totalRatings > 0 {
                            BentoMerchantRatingRow(merchant: merchant)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(GravitySpacing.space12)
            }
            .overlay(alignment: .bottom) {
                if geo.size.height > geo.size.width * 1.2 {
                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products.prefix(2)) { item in
                            chip(item, side: (geo.size.width - GravitySpacing.space12 * 2 - GravitySpacing.space8) / 2)
                        }
                    }
                    .padding(GravitySpacing.space12)
                }
            }
        }
    }

    private func chip(_ item: ResolvedStoryProduct, side: CGFloat) -> some View {
        Button {
            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
        } label: {
            // Product floats fitted inside the white chip with breathing room.
            RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                .fill(.white)
                .frame(width: side, height: side)
                .overlay {
                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(width: side - 14, height: side - 14)
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous))
                }
                .overlay(alignment: .topLeading) {
                    Text(formatPrice(item.product.price))
                        .gravityTextStyle(GravityTypography.badgeBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GravityRadius.max))
                        .environment(\.colorScheme, .dark)
                        .padding(6)
                }
                .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(.plain)
    }
}

/// Floating shop discs, no card chrome: 2 across, as many rows as the cell
/// height allows (2×2 square, 2×3 tall). Each disc opens its store.
private struct BentoAvatarClusterCell: View {
    let merchants: [SampleMerchant]

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        GeometryReader { geo in
            let spacing = GravitySpacing.space12
            let diameter = (geo.size.width - spacing) / 2
            let rowCount = max(1, Int((geo.size.height + spacing) / (diameter + spacing)))
            let visible = Array(merchants.prefix(rowCount * 2))
            let rows = stride(from: 0, to: visible.count, by: 2).map {
                Array(visible[$0..<min($0 + 2, visible.count)])
            }
            VStack(spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: spacing) {
                        ForEach(row) { merchant in
                            Button {
                                coordinator.pushRoute(.store(merchantId: merchant.id))
                            } label: {
                                // Brand-color disc when it's light enough to
                                // carry a dark mark; white keeps transparent
                                // wordmark logos legible otherwise.
                                MerchantLogoImage(merchant: merchant, size: diameter)
                                    .background(Circle().fill(discColor(for: merchant)))
                                    .gravityShadow(GravityShadows.small)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func discColor(for merchant: SampleMerchant) -> Color {
        let color = merchant.primaryColor
        var brightness: CGFloat = 0
        UIColor(color).getWhite(&brightness, alpha: nil)
        return brightness > 0.55 ? color : .white
    }
}

#Preview("Birding-style bento") {
    let merchant = SampleMerchant.preview
    let products = merchant.products.prefix(4).map { ResolvedStoryProduct(merchant: merchant, product: $0) }
    ScrollView {
        BentoGrid(
            compartments: [
                .init(id: "0", role: "See", size: .hero, surface: .product(products[0]), action: {}),
                .init(id: "1", role: "See", size: .standard, surface: .product(products[1]), action: {}),
                .init(id: "2", role: "Wear", size: .standard, surface: .product(products[2]), action: {}),
                .init(id: "3", role: "Carry", size: .standard, surface: .product(products[3]), action: {}),
                .init(id: "4", role: "Shop the world", size: .wide, surface: .merchant(merchant), action: {}),
            ],
            containerWidth: 361
        )
        .padding(16)
    }
    .background(Color(hex: "#2C2E24"))
    .environment(\.colorScheme, .dark)
    .environment(NavigationCoordinator())
}

#Preview("Brand-forward bento") {
    let merchants = SampleMerchant.previews
    let merchant = merchants[0]
    let products = merchant.products.prefix(4).map { ResolvedStoryProduct(merchant: merchant, product: $0) }
    ScrollView {
        BentoGrid(
            compartments: [
                .init(id: "0", role: "Keep shopping", size: .hero, surface: .product(products[0]), action: {}),
                .init(id: "1", role: "Meet the maker", size: .standard, surface: .merchantSpotlight(merchant, Array(products.prefix(2))), action: {}),
                .init(id: "2", role: "See", size: .standard, surface: .product(products[1]), action: {}),
                .init(id: "3", role: "Wear", size: .standard, surface: .product(products[2]), action: {}),
                .init(id: "4", role: "Carry", size: .standard, surface: .product(products[3]), action: {}),
                .init(id: "5", role: "Browse the shops", size: .standard, surface: .avatarCluster(Array(merchants.prefix(4))), action: {}),
                .init(id: "6", role: "Shop the world", size: .wide, surface: .merchant(merchant), action: {}),
            ],
            containerWidth: 361
        )
        .padding(16)
    }
    .background(Color(hex: "#2C2E24"))
    .environment(\.colorScheme, .dark)
    .environment(NavigationCoordinator())
}

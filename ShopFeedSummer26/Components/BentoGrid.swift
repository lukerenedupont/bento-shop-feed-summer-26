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
                if run.count == 1 {
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

/// The compartment shell: ambient surface, bottom legibility scrim, and
/// title. Roles stay data-side (sizing + validator contract) — the imagery
/// carries the cell, and dossier films will fill these surfaces as they land.
private struct BentoCompartmentCard: View {
    let compartment: BentoCompartment

    var body: some View {
        Button(action: compartment.action) {
            ZStack(alignment: .bottomLeading) {
                surface

                // Bottom-only scrim for the title; the top of the cell
                // stays untouched so the asset reads clean.
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

    @ViewBuilder
    private var surface: some View {
        switch compartment.surface {
        case .product(let item):
            AmbientProductVideo(product: item.product, merchant: item.merchant)
        case .merchant(let merchant):
            ZStack {
                Color.clear.overlay { MerchantCoverImage(merchant: merchant) }.clipped()
            }
            .overlay(alignment: .center) {
                MerchantLogoImage(merchant: merchant, size: 52)
            }
        case .story(let story, let hero):
            if let hero, let film = DossierStore.ambientVideoURL(merchantID: hero.merchant.id, productID: hero.product.id) {
                AmbientProductVideo(videoURL: film, posterImageURL: hero.product.imageURL)
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
        case .story(let story, _): return story.title
        }
    }

    private var price: String? {
        switch compartment.surface {
        case .product(let item): return formatPrice(item.product.price)
        case .merchant, .story: return nil
        }
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
}

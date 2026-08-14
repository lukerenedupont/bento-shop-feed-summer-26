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
/// the full width; standard cells pair up. Layout is deterministic from the
/// compartment order — curation stays in data, not in layout heuristics.
struct BentoGrid: View {
    let compartments: [BentoCompartment]
    let containerWidth: CGFloat

    private let spacing: CGFloat = GravitySpacing.space8
    private var columnWidth: CGFloat { (containerWidth - spacing) / 2 }

    private func height(for size: BentoCellSize) -> CGFloat {
        switch size {
        case .hero: return 420
        case .wide: return 180
        // Paired cells are 1:1 — same square grammar as ProductCard tiles.
        case .standard: return columnWidth
        }
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(spacing: spacing) {
                    ForEach(row) { compartment in
                        BentoCompartmentCard(compartment: compartment)
                            .frame(
                                width: row.count == 1 && compartment.size != .standard ? containerWidth : columnWidth,
                                height: height(for: compartment.size)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: containerWidth)
    }

    /// Full-width cells get their own row; standard cells pair greedily.
    private var rows: [[BentoCompartment]] {
        var rows: [[BentoCompartment]] = []
        var pending: BentoCompartment?
        for compartment in compartments {
            if compartment.size == .standard {
                if let waiting = pending {
                    rows.append([waiting, compartment])
                    pending = nil
                } else {
                    pending = compartment
                }
            } else {
                if let waiting = pending {
                    rows.append([waiting])
                    pending = nil
                }
                rows.append([compartment])
            }
        }
        if let waiting = pending { rows.append([waiting]) }
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

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: compartment.size == .hero ? 22 : 15, weight: .bold))
                        .tracking(-0.3)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }
                .padding(12)
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

    private var subtitle: String? {
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
                .init(id: "3", role: "Shop the world", size: .wide, surface: .merchant(merchant), action: {}),
                .init(id: "4", role: "Carry", size: .standard, surface: .product(products[3]), action: {}),
            ],
            containerWidth: 361
        )
        .padding(16)
    }
    .background(Color(hex: "#2C2E24"))
    .environment(\.colorScheme, .dark)
}

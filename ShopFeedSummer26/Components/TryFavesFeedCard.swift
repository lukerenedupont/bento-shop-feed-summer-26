import SwiftUI

enum TryFavesExperience {
    /// World ID, feed entry ID, and shared-view transition source for the
    /// "Try your faves" prototype.
    static let cardID = "try-your-faves"
}

/// The Home feed entry for the Try your faves world: the seed avatar on its
/// stage with a slice of the shopper's try-on-ready favorites.
///
/// The tiles, radii, and type here are the same ones the world uses, so the
/// zoom into the world changes scale and nothing else.
struct TryFavesFeedCard: View {
    let width: CGFloat
    let height: CGFloat
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var titleTrailingPadding: CGFloat = 0
    var scrollPinnedTitleTop: CGFloat? = nil
    let onTap: () -> Void

    /// The home card presents the seed outfit as a pre-generated look.
    @State private var garments = TryFavesCatalog.seedLookGarments
    @State private var service = TryFavesLookService.shared

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            ZStack {
                TryFavesStyle.canvas

                // The buyer's seed photograph fills the card edge to edge —
                // the bundled photograph until their generated seed lands.
                if let seed = service.seedRenderImage() {
                    Image(uiImage: seed)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                }

                VStack(alignment: .leading, spacing: 0) {
                    scrollAwareTitle

                    Spacer(minLength: GravitySpacing.space16)

                    garmentRow
                }
                .padding(.horizontal, FeedCardStyle.foregroundHorizontalPadding)
                .padding(.top, foregroundTopPadding)
                .padding(.bottom, FeedCardStyle.foregroundBottomPadding)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: FeedCardStyle.cornerRadius, style: .continuous)
                    .strokeBorder(TryFavesStyle.tileBorder, lineWidth: 0.5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.07), radius: 16, y: 3)
        }
        .buttonStyle(.plain)
        // Pre-generate the active buyer's seed first, then every other
        // buyer's in the background, so switching profiles lands on a
        // customized photograph instead of the bundled fallback.
        .task(id: BuyerPreviewStore.shared.selected.id) {
            service.syncBuyerIfNeeded()
            service.ensureSeed()
            service.ensureAllSeeds()
        }
        .accessibilityLabel("Try on your favorites")
        .accessibilityHint("Opens your avatar to style saved products into looks")
    }

    private var title: some View {
        Text("Try on your favorites")
            .feedCardTitleStyle()
            .foregroundStyle(TryFavesStyle.stageText)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .padding(.trailing, titleTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// How much higher than the shared pinned-title line the headline rests
    /// once the card is swiped into place. The feedback icons overlaid by
    /// Home rise by the same amount so they stay top-aligned with the title.
    static let pinnedTitleRaise: CGFloat = 24

    private var scrollAwareTitle: some View {
        let pinnedTop = scrollPinnedTitleTop.map { $0 - Self.pinnedTitleRaise }
        return title
            .visualEffect { title, proxy in
                title.offset(
                    y: max(
                        0,
                        (pinnedTop
                            ?? proxy.frame(in: .scrollView(axis: .vertical)).minY)
                            - proxy.frame(in: .scrollView(axis: .vertical)).minY
                    )
                )
            }
    }

    /// Full-width three-column product grid with a "Try more ›" section
    /// header below, per the Hyperfeed card design.
    private var garmentRow: some View {
        let tileSide = (width - FeedCardStyle.foregroundHorizontalPadding * 2 - GravitySpacing.space8 * 2) / 3

        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(alignment: .top, spacing: GravitySpacing.space8) {
                ForEach(garments) { garment in
                    TryFavesProductTile(
                        garment: garment,
                        width: tileSide,
                        accessory: .price
                    )
                }
            }

            HStack(spacing: GravitySpacing.space4) {
                Text("Try more")
                    .gravityTextStyle(GravityTypography.sectionTitle)
                    .foregroundStyle(TryFavesStyle.stageText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TryFavesStyle.stageText)
            }
            .padding(.leading, GravitySpacing.space4)
        }
    }
}

#Preview("Try faves feed card") {
    TryFavesFeedCard(width: 345, height: 590) {}
        .padding()
        .background(Color(hex: "#EAE6E1"))
}

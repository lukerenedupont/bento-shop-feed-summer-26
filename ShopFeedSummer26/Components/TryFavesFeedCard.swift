import SwiftUI

enum TryFavesExperience {
    /// World ID, feed entry ID, and shared-view transition source for the
    /// "Try your faves" prototype.
    static let cardID = "try-your-faves"
}

/// The Home feed entry for the Try your faves world: the seed avatar on the
/// cream stage with a slice of the shopper's try-on-ready favorites.
struct TryFavesFeedCard: View {
    let width: CGFloat
    let height: CGFloat
    var foregroundTopPadding: CGFloat = GravitySpacing.space20
    var titleTrailingPadding: CGFloat = 0
    var scrollPinnedTitleTop: CGFloat? = nil
    let onTap: () -> Void

    /// The home card presents the seed outfit as a pre-generated look.
    @State private var garments = TryFavesCatalog.seedLookGarments

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            ZStack {
                TryFavesStyle.canvas

                // The editorial seed photograph fills the card edge to edge.
                Image(TryFavesLookService.seedAvatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()

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
                    .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.07), radius: 16, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Try on your favorites")
        .accessibilityHint("Opens your avatar to style saved products into looks")
    }

    private var title: some View {
        Text("Try on your favorites")
            .feedCardTitleStyle()
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .padding(.trailing, titleTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scrollAwareTitle: some View {
        title
            .visualEffect { title, proxy in
                title.offset(
                    y: max(
                        0,
                        (scrollPinnedTitleTop
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
                    gridTile(garment, side: tileSide)
                }
            }

            HStack(spacing: GravitySpacing.space4) {
                Text("Try more")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(.black)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
            }
            .padding(.leading, GravitySpacing.space4)
        }
    }

    private func gridTile(_ garment: TryOnGarment, side: CGFloat) -> some View {
        ZStack {
            Color.white
            if let url = URL(string: garment.imageURL) {
                CachedAsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.white
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(hex: "#05294D").opacity(0.1), lineWidth: 0.5)
        }
        .overlay(alignment: .topLeading) {
            Text(garment.displayPrice)
                .font(.system(size: 10, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space6)
                .padding(.vertical, GravitySpacing.space2)
                .background(.black.opacity(0.3), in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .padding(GravitySpacing.space10)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

#Preview("Try faves feed card") {
    TryFavesFeedCard(width: 345, height: 590) {}
        .padding()
        .background(Color(hex: "#EAE6E1"))
}

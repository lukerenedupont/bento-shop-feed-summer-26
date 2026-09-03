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

    @State private var garments = Array(TryFavesCatalog.garments.prefix(3))

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            ZStack {
                TryFavesStyle.canvas

                Image(TryFavesLookService.seedAvatarAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height, alignment: .bottom)
                    .scaleEffect(0.86, anchor: .bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

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
        Text("Try on your favorites.")
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

    private var garmentRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(garments) { garment in
                Group {
                    if let url = URL(string: garment.imageURL) {
                        CachedAsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.white
                            }
                        }
                    } else {
                        Color.white
                    }
                }
                .frame(width: 64, height: 64)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                }
            }

            Spacer(minLength: 0)

            Text("Try more")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, GravitySpacing.space12)
                .frame(height: 32)
                .background(.white.opacity(0.85), in: Capsule())
        }
    }
}

#Preview("Try faves feed card") {
    TryFavesFeedCard(width: 345, height: 590) {}
        .padding()
        .background(Color(hex: "#EAE6E1"))
}

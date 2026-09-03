import SwiftUI

/// The single product tile behind every Try your faves surface — the Home
/// feed card's grid, the look panel's rail, and the composer's rails.
///
/// Only the accessory and the meta block change between them; the well,
/// radius, hairline, and shadow never do, so a product reads identically
/// wherever the shopper meets it.
struct TryFavesProductTile: View {

    /// The affordance drawn over the image well.
    enum Accessory: Equatable {
        case none
        /// Home feed card: price capsule, top leading, over the photography.
        case price
        /// Look panel: the shopper can favourite the garment they are wearing.
        case favorite
        /// Composer: the garment is part of the outfit being assembled.
        case selection(isSelected: Bool)
    }

    let garment: TryOnGarment
    let width: CGFloat
    var accessory: Accessory = .none
    /// Merchant, product, price beneath the well. Only the look panel shows
    /// it, and only ever over the light stage photography.
    var showsMeta: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            imageWell
            if showsMeta { meta }
        }
        .frame(width: width)
    }

    private var imageWell: some View {
        ZStack {
            TryFavesStyle.tileWell
            if let url = URL(string: garment.imageURL) {
                CachedAsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        TryFavesStyle.tileWell
                    }
                }
            }
        }
        .frame(width: width, height: width)
        .clipShape(RoundedRectangle(cornerRadius: TryFavesStyle.tileRadius, style: .continuous))
        .overlay(alignment: .topLeading) { priceCapsule }
        .overlay(alignment: .bottomTrailing) { cornerAffordance }
        // The hairline never changes with selection: the check is the whole
        // affordance, and a ring on a white product photo reads as nothing.
        .overlay {
            RoundedRectangle(cornerRadius: TryFavesStyle.tileRadius, style: .continuous)
                .strokeBorder(TryFavesStyle.tileBorder, lineWidth: 0.5)
        }
        .gravityShadow(TryFavesStyle.tileShadow)
    }

    @ViewBuilder
    private var priceCapsule: some View {
        if accessory == .price {
            Text(garment.displayPrice)
                .gravityTextStyle(GravityTypography.badgeBold)
                .foregroundStyle(GravityColors.textFixedLight)
                .padding(.horizontal, GravitySpacing.space6)
                .padding(.vertical, GravitySpacing.space2)
                .background(GravityColors.bgOverlayFixedDark30, in: Capsule())
                .background(.ultraThinMaterial, in: Capsule())
                .padding(GravitySpacing.space10)
        }
    }

    /// Both corner affordances sit in the design's 48pt tap area, flush to the
    /// bottom-trailing corner, with the glyph centred 24pt in from each edge.
    @ViewBuilder
    private var cornerAffordance: some View {
        switch accessory {
        case .favorite:
            favoriteHeart
                .frame(width: 48, height: 48)
        case let .selection(isSelected):
            selectionCheck(isSelected: isSelected)
                .frame(width: 48, height: 48)
        case .none, .price:
            EmptyView()
        }
    }

    /// An unfilled dark hairline heart — quiet over the white tile wells.
    private var favoriteHeart: some View {
        GravityIcon.favorites.image
            .resizable()
            .scaledToFit()
            .foregroundStyle(GravityColors.textFixedDark.opacity(0.55))
            .frame(width: 24, height: 24)
    }

    private func selectionCheck(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isSelected
                      ? AnyShapeStyle(GravityColors.bgFillFixedLight)
                      : AnyShapeStyle(GravityColors.bgOverlayFixedDark20))
            GravityIcon.checkmark.image
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(isSelected
                                 ? GravityColors.textFixedDark
                                 : GravityColors.textFixedLight)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }

    /// Merchant, product, price — three 16pt lines in a pinned 48pt block, so
    /// a missing merchant or a wrapping title can never change the rail's
    /// height. Fixed white stage type: this only ever sits on the stage
    /// photography.
    private var meta: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(garment.shop)
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(TryFavesStyle.stageTextSecondary)
                .lineLimit(1)
            Text(garment.title)
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(TryFavesStyle.stageText)
                .lineLimit(1)
            Text(garment.displayPrice)
                .gravityTextStyle(GravityTypography.captionBold)
                .foregroundStyle(TryFavesStyle.stageText)
                .lineLimit(1)
        }
        .frame(width: width, height: TryFavesStyle.tileMetaHeight, alignment: .topLeading)
    }
}

#Preview("Product tiles") {
    let garments = Array(TryFavesCatalog.garments.prefix(3))
    return VStack(alignment: .leading, spacing: GravitySpacing.space24) {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(garments) { garment in
                TryFavesProductTile(
                    garment: garment,
                    width: TryFavesStyle.lookTileWidth,
                    accessory: .favorite,
                    showsMeta: true
                )
            }
        }
        HStack(spacing: GravitySpacing.space8) {
            ForEach(Array(garments.enumerated()), id: \.element.id) { index, garment in
                TryFavesProductTile(
                    garment: garment,
                    width: TryFavesStyle.composerTileWidth,
                    accessory: .selection(isSelected: index == 0)
                )
            }
        }
        .padding(GravitySpacing.space16)
        .background(GravityColors.bgFillFixedDusk, in: RoundedRectangle(cornerRadius: GravityRadius.r24))
    }
    .padding(GravitySpacing.space16)
    .background(TryFavesStyle.canvas)
}

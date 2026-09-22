import Gravity
import SwiftUI

struct ShopRemoteImageFannedStack: View {
    enum Size: CGFloat {
        case xSmall = 32
        case small = 40
        case medium = 48
        case large = 64
        case xLarge = 72
    }

    enum Gap: CGFloat {
        case small = 2
        case medium = 4
        case large = 8
    }

    /// A `nil` entry renders the placeholder in that tile's slot, so a caller can fan one tile per
    /// subject even when some subjects have no imagery. Non-optional arrays convert implicitly, so
    /// existing callers are unaffected.
    let images: [ShopRemoteImageModel?]
    var size: Size = .medium
    var gap: Gap = .medium
    var placeholderIcon: GravityIconName = .noImage
    var placeholderImage: String? = nil
    var cornerRadius: CGFloat = GravityRadius.radius8
    var reservesFanOverflow: Bool = false

    private var visibleImages: [ShopRemoteImageModel?] {
        Array(images.prefix(3))
    }

    var body: some View {
        ShopFannedImageStack(
            itemCount: visibleImages.count,
            size: primitiveSize,
            gap: primitiveGap,
            reservesOverflowInLayout: reservesFanOverflow
        ) { index in
            if let image = visibleImages[index] {
                imageView(image)
            } else {
                placeholder
            }
        } placeholder: {
            placeholder
        }
    }

    private var primitiveSize: ShopFannedImageStackSize {
        switch size {
        case .xSmall:
            .xSmall
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        case .xLarge:
            .xLarge
        }
    }

    private var primitiveGap: ShopFannedImageStackGap {
        switch gap {
        case .small:
            .small
        case .medium:
            .medium
        case .large:
            .large
        }
    }

    private var placeholder: some View {
        ZStack {
            if let placeholderImage {
                // `bgOverlayFixedDark04` is a 4%-alpha tint, so it needs an opaque base underneath.
                // Without one the tile behind it in a fan showed straight through, which read as a
                // translucent stack. This was invisible while placeholders only ever rendered alone.
                // The composite is unchanged for those callers: an opaque surface plus a 4% tint is
                // what a 4% tint over the surface already looked like. Android gets this from
                // `ShopFannedImageSurface`, which backs every tile with `BgFillFixedLight`.
                GravityColor.bgFill
                GravityColor.bgOverlayFixedDark04
                Image(placeholderImage)
                    .resizable()
                    .scaledToFill()
            } else {
                GravityColor.bgFill
                ShopIcon(placeholderIcon, size: .large, color: GravityColor.textPlaceholder)
            }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(ShopImageBorderOverlay(cornerRadius: cornerRadius))
        .gravityShadow(.s)
    }

    private func imageView(_ image: ShopRemoteImageModel) -> some View {
        ZStack {
            GravityColor.bgFill
            ShopRemoteImage(
                image: image,
                displaySize: CGSize(width: size.rawValue, height: size.rawValue),
                contentMode: .fill
            )
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(ShopImageBorderOverlay(cornerRadius: cornerRadius))
        .gravityShadow(.s)
    }
}

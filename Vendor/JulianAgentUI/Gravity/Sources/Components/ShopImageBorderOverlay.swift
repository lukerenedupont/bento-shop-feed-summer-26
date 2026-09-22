import SwiftUI

/// Border overlay for rounded image surfaces.
///
/// Use this as an overlay on image containers when the image itself is clipped
/// by the parent. This mirrors RN `ShopImageBorderOverlay`, where border radius,
/// width, and color are the only styling controls.
public struct ShopImageBorderOverlay: View {
    private let cornerRadius: CGFloat
    private let borderWidth: CGFloat
    private let borderColor: Color

    public init(
        cornerRadius: CGFloat = GravityRadius.radius20,
        borderWidth: CGFloat = 0.5,
        borderColor: Color = GravityColor.borderImage
    ) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.borderColor = borderColor
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(borderColor, lineWidth: borderWidth)
            .allowsHitTesting(false)
    }
}

#Preview("ShopImageBorderOverlay") {
    RoundedRectangle(cornerRadius: GravityRadius.radius20, style: .continuous)
        .fill(GravityColor.bgFillSecondary)
        .frame(width: 120, height: 120)
        .overlay(ShopImageBorderOverlay())
        .padding()
        .background(GravityColor.bg)
}

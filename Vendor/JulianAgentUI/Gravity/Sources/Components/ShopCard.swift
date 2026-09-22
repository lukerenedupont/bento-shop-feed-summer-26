import SwiftUI

public struct ShopCard<Content: View>: View {
    private let shadow: GravityShadowLevel
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let backgroundColor: Color
    private let borderColor: Color
    private let content: Content

    public init(
        shadow: GravityShadowLevel = .s,
        cornerRadius: CGFloat = GravityRadius.radius20,
        padding: CGFloat = GravitySpacing.cardPadding,
        backgroundColor: Color = GravityColor.bgFill,
        borderColor: Color = GravityColor.borderImage,
        @ViewBuilder content: () -> Content
    ) {
        self.shadow = shadow
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .gravityPathShadow(shadow, shape: .roundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview("ShopCard") {
    VStack(spacing: GravitySpacing.space16) {
        ShopCard(shadow: .none) {
            ShopText("Flat card", style: .sectionTitle)
        }
        ShopCard {
            ShopText("Elevated card", style: .sectionTitle)
        }
    }
    .padding()
}

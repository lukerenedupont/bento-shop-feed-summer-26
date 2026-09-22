import SwiftUI

public struct ShopifyLogoWordmark: View {
    private let width: CGFloat
    private let height: CGFloat
    private let color: Color?

    public init(width: CGFloat = 63, height: CGFloat = 18, color: Color? = nil) {
        self.width = width
        self.height = height
        self.color = color
    }

    public var body: some View {
        renderedImage
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var renderedImage: some View {
        if let color {
            Image("shopifyLogo", bundle: .gravityResources)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
        } else {
            Image("shopifyLogo", bundle: .gravityResources)
                .resizable()
                .scaledToFit()
        }
    }
}

#Preview {
    ShopifyLogoWordmark()
        .padding()
}

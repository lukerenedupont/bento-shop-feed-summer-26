import SwiftUI

public struct ShopWordmark: View {
    private let width: CGFloat
    private let height: CGFloat
    private let color: Color
    private let accessibilityLabel: String?

    public init(
        width: CGFloat = 128,
        height: CGFloat = 64,
        color: Color = GravityColor.textBrand,
        accessibilityLabel: String? = "Shop"
    ) {
        self.width = width
        self.height = height
        self.color = color
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        applyAccessibility(
            to: Image("shopWordmark", bundle: .gravityResources)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .frame(width: width, height: height)
        )
    }

    @ViewBuilder
    private func applyAccessibility<Content: View>(to content: Content) -> some View {
        if let accessibilityLabel {
            content.accessibilityLabel(SwiftUI.Text(accessibilityLabel))
        } else {
            content.accessibilityHidden(true)
        }
    }
}

#Preview {
    ShopWordmark()
        .padding()
}

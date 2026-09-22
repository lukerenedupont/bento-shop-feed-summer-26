import SwiftUI

public struct ShopDivider: View {
    private let color: Color

    public init(color: Color = GravityColor.borderSecondary) {
        self.color = color
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

#Preview("ShopDivider") {
    VStack(spacing: GravitySpacing.space16) {
        ShopText("Above")
        ShopDivider()
        ShopText("Below")
    }
    .padding()
}

import SwiftUI

public struct ShopProgressBar: View {
    private let progress: Double
    private let height: CGFloat
    private let color: Color
    private let trackColor: Color

    public init(
        progress: Double,
        height: CGFloat = 6,
        color: Color = GravityColor.bgFillBrand,
        trackColor: Color = GravityColor.bgFillSecondary
    ) {
        self.progress = progress
        self.height = height
        self.color = color
        self.trackColor = trackColor
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(trackColor)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(SwiftUI.Text("\(Int(min(max(progress, 0), 1) * 100))%"))
    }
}

#Preview("ShopProgressBar") {
    VStack(spacing: GravitySpacing.space16) {
        ShopProgressBar(progress: 0.25)
        ShopProgressBar(progress: 0.6)
        ShopProgressBar(progress: 1)
    }
    .padding()
}

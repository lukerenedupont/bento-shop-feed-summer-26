import SwiftUI

public struct ShopPressScaleButtonStyle: ButtonStyle {
    private let scale: CGFloat
    private let opacity: Double

    public init(
        scale: CGFloat = 0.97,
        opacity: Double = 1
    ) {
        self.scale = scale
        self.opacity = opacity
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? opacity : 1)
            .animation(ShopMotion.press, value: configuration.isPressed)
    }
}

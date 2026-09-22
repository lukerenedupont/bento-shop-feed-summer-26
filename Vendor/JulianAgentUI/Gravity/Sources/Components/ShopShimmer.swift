import SwiftUI

public struct ShopShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    private let opacity: Double
    private let widthRatio: CGFloat

    public init(
        opacity: Double = 0.18,
        widthRatio: CGFloat = 0.48
    ) {
        self.opacity = opacity
        self.widthRatio = widthRatio
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(opacity),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width * widthRatio)
                        .offset(x: phase * proxy.size.width * (1 + widthRatio))
                    }
                }
                .clipped()
                .onAppear {
                    phase = -1
                    withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

public extension View {
    func shopShimmer(
        opacity: Double = 0.18,
        widthRatio: CGFloat = 0.48
    ) -> some View {
        modifier(ShopShimmerModifier(opacity: opacity, widthRatio: widthRatio))
    }
}

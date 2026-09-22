import SwiftUI

private struct ShopFadeInModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    let staggerIndex: Int

    private var staggerDelay: TimeInterval {
        guard reduceMotion == false else { return 0 }
        let step = min(max(staggerIndex, 0), 3)
        return TimeInterval(step * GravityMotion.durationShortMilliseconds) / 1_000
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(ShopMotion.entrance.delay(staggerDelay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

public extension View {
    /// Fades the view in once on appearance. Stagger index 0 starts immediately;
    /// subsequent indices use 100 ms steps capped at 300 ms. Reduce Motion skips the stagger.
    func shopFadeIn(staggerIndex: Int = 0) -> some View {
        modifier(ShopFadeInModifier(staggerIndex: staggerIndex))
    }
}

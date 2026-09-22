import Gravity
import SwiftUI

enum ShopAgentFloatingSurfaceMetrics {
    static let controlSize: CGFloat = 56
    static let borderWidth: CGFloat = 0.5
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 6
}

private struct ShopAgentFloatingSurfaceShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(
                color: GravityColor.shadow300,
                radius: ShopAgentFloatingSurfaceMetrics.shadowRadius,
                x: 0,
                y: ShopAgentFloatingSurfaceMetrics.shadowYOffset
            )
            .gravityShadow(.s)
    }
}

extension View {
    func shopAgentFloatingSurfaceShadow() -> some View {
        modifier(ShopAgentFloatingSurfaceShadowModifier())
    }
}

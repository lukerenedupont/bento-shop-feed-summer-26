import Gravity
import SwiftUI

extension EnvironmentValues {
    @Entry var shopConversationStarterIsVisible = true
}

/// Shared interactive material for personalized and generic conversation starters.
struct ShopConversationStarterGlass: ViewModifier {
    static let enabledStorageKey = "shop.prototype.conversation-starter-glass-enabled"

    let tint: Color?
    @AppStorage(ShopConversationStarterGlass.enabledStorageKey) private var isGlassEnabled = true
    @Environment(\.shopConversationStarterIsVisible) private var isVisible
    @Environment(\.shopConversationStarterPresentation) private var presentation
    @Namespace private var glassNamespace

    func body(content: Content) -> some View {
        // Give draft tints a little more presence without fading the foreground
        // or changing the existing inline treatment.
        let softenedTint = tint?.opacity(presentation == nil ? 0.5 : 0.6)
        if isVisible {
            if #available(iOS 26, *) {
                content
                    .background {
                        if !isGlassEnabled {
                            // The draft already has a blur curtain. Let its pixels
                            // show through the tint instead of adding an opaque base.
                            Capsule().fill(presentation == nil ? GravityColor.bg : .clear)
                                .overlay(Capsule().fill(softenedTint ?? .clear))
                        }
                    }
                    .glassEffect(
                        isGlassEnabled ? .regular.tint(softenedTint).interactive() : .identity,
                        in: .capsule
                    )
                    .glassEffectID("starter", in: glassNamespace)
                    .glassEffectTransition(.materialize)
            } else {
                content.background {
                    if isGlassEnabled {
                        Capsule().fill(.ultraThinMaterial)
                            .background(softenedTint ?? .clear, in: Capsule())
                    } else {
                        Capsule().fill(presentation == nil ? GravityColor.bg : .clear)
                            .overlay(Capsule().fill(softenedTint ?? .clear))
                    }
                }
                    .transition(.opacity)
            }
        } else {
            // Preserve the exact row size without keeping invisible glass in
            // the container. Native materialize owns the outgoing material.
            content.hidden()
        }
    }
}

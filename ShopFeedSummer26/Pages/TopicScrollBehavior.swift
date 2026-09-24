import SwiftUI

/// Shared World scrolling policy, extracted from the bounded topic host.
struct TopicScrollBehavior: ViewModifier {
    let isPersonalEdit: Bool
    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, isPersonalEdit ? 0 : (ShopCanvasLibrary.isEnabled ? 144 : 0), for: .scrollContent)
            .scrollBounceBehavior(.basedOnSize)
            .modifier(WorldDragScrollLock())
    }
}

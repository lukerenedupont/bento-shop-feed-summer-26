import SwiftUI

/// Supplies the current width of this local container, not the screen or window.
///
/// Place outside a horizontal shelf/carousel, at the boundary that owns its available width.
/// Padding and edge bleed remain the caller's responsibility. The height stays intrinsic, so
/// this host can be used in vertically self-sizing content. Keep `content` mounted when width
/// is nil (the initial layout pass); optional `.frame(width:)` is suitable for that bootstrap.
///
/// Only a meaningful width change is published. Height changes and scrolling do not republish
/// width, and no dimensions are broadcast through the environment or a screen state owner.
public struct ShopContainerWidthHost<Content: View>: View {
    @State private var availableWidth: CGFloat?
    private let content: (CGFloat?) -> Content

    public init(@ViewBuilder content: @escaping (CGFloat?) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(availableWidth)
            // Both constraints adopt the immediate parent's finite width even when a shelf's
            // children still report the previous (larger) card width during a shrinking pass.
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                guard width.isFinite, width > 0,
                      availableWidth.map({ abs($0 - width) > 0.5 }) ?? true else {
                    return
                }
                availableWidth = width
            }
    }
}

import SwiftUI
import Gravity
import UIKit

enum ShopTabBarMetrics {
    static let bottomSpacing: CGFloat = GravitySpacing.space8
    static let maximumVisualBottomInset: CGFloat = GravitySpacing.space20
    static let topPadding: CGFloat = GravitySpacing.space12
    static let contentHeight: CGFloat = 56
    static let backdropHeight: CGFloat = contentHeight + bottomSpacing + GravitySpacing.space4
    static let contentClearanceAboveSafeArea: CGFloat = contentHeight + bottomSpacing
    static let reservedHeight: CGFloat = 104

    static func visualBottomPadding(for bottomInset: CGFloat) -> CGFloat {
        min(bottomInset, maximumVisualBottomInset) + bottomSpacing
    }

    /// Height the floating chrome covers at the bottom of the window.
    static func occludedWindowBottomHeight(for bottomInset: CGFloat) -> CGFloat {
        visualBottomPadding(for: bottomInset) + contentHeight
    }

    static func pinnedContentBottomPadding(
        for bottomInset: CGFloat,
        gap: CGFloat = GravitySpacing.screenMargin
    ) -> CGFloat {
        occludedWindowBottomHeight(for: bottomInset) + gap
    }

    static func pinnedContentBottomPaddingInsideSafeArea(
        for bottomInset: CGFloat,
        gap: CGFloat = GravitySpacing.screenMargin
    ) -> CGFloat {
        max(pinnedContentBottomPadding(for: bottomInset, gap: gap) - bottomInset, gap)
    }
}


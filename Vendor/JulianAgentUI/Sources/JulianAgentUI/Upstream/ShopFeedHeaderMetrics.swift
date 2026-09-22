import SwiftUI
import Gravity
import UIKit

enum ShopFeedHeaderMetrics {
    static let navigationBarHeight: CGFloat = ShopSpacing.space44
    static let contentSpacing: CGFloat = ShopSpacing.space12
    static let quickLinksExtraHeight: CGFloat = ShopSpacing.space20
    static let quickLinksBarHeight: CGFloat = ShopSpacing.space48
    static let quickLinksItemHeight: CGFloat = ShopSpacing.space40
    static let quickLinksIconSize: CGFloat = ShopSpacing.space20
    static let quickLinksAccountAvatarSize: CGFloat = ShopSpacing.space32
    static let quickLinksContentBottomPadding: CGFloat = ShopSpacing.space8
    static let backdropBaseHeight: CGFloat = 120
    static let backdropBlurAmount: CGFloat = 20
    static let backdropScrimOpacity: CGFloat = 0.1
    static let backdropProgressUpdateThreshold: CGFloat = 0.001
    /// Top content gap for screens that use the system navigation bar instead of
    /// the custom overlay header. The system bar already provides the bar and
    /// safe-area spacing, so the feed only needs a small gap below it.
    static let systemNavigationBarContentInset: CGFloat = contentSpacing

    static func topContentInset(safeAreaTopInset: CGFloat) -> CGFloat {
        safeAreaTopInset + navigationBarHeight + contentSpacing
    }

    static func navigationChromeHeight(safeAreaTopInset: CGFloat) -> CGFloat {
        safeAreaTopInset + navigationBarHeight
    }

    static func quickLinksChromeHeight(safeAreaTopInset: CGFloat) -> CGFloat {
        navigationChromeHeight(safeAreaTopInset: safeAreaTopInset) + quickLinksExtraHeight
    }

    static func backdropHeight(safeAreaTopInset: CGFloat) -> CGFloat {
        max(backdropBaseHeight, navigationChromeHeight(safeAreaTopInset: safeAreaTopInset))
    }
}

@MainActor
@Observable
final class ShopFeedHeaderBackdropProgressState {
    var progress: CGFloat = 0

    func setProgress(_ nextProgress: CGFloat) {
        guard abs(nextProgress - progress) > ShopFeedHeaderMetrics.backdropProgressUpdateThreshold else {
            return
        }

        progress = nextProgress
    }
}


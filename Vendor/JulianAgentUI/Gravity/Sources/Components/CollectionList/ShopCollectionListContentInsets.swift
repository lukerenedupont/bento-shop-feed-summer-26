import UIKit

public struct ShopCollectionListContentInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static let zero = ShopCollectionListContentInsets()
}

public enum ShopCollectionListContentInsetAdjustmentBehavior: Equatable, Sendable {
    /// Feed/custom-chrome style: the collection view receives only the explicit
    /// `contentInsets` supplied by the caller.
    case never

    /// System-navigation style: UIKit may add safe-area/navigation-bar adjusted
    /// insets, matching native scroll views inside a `NavigationStack`.
    case automatic

    var uiKitValue: UIScrollView.ContentInsetAdjustmentBehavior {
        switch self {
        case .never:
            .never
        case .automatic:
            .automatic
        }
    }

    /// Only system-navigation lists should claim the enclosing navigation controller's
    /// content-scroll-view slot. Permanently mounted custom-chrome lists (such as Cart) use
    /// `.never`; registering one of those can steal large-title collapse from the visible screen.
    var participatesInSystemNavigationChrome: Bool {
        self == .automatic
    }
}

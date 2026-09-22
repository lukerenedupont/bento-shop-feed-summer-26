import CoreGraphics

/// Layout strategy for `ShopCollectionList`.
///
/// The default vertical layout self-sizes SwiftUI rows. The custom hook keeps
/// the shared list foundation open to specialized layouts without forcing
/// app-specific behavior into the generic list.
public enum ShopCollectionListLayout {
    case vertical(
        rowSpacing: CGFloat = 0,
        estimatedRowHeight: CGFloat = 88,
        estimatedHeaderHeight: CGFloat = 44
    )
    case custom(ShopCollectionListCustomLayout)

    var identity: String {
        switch self {
        case let .vertical(rowSpacing, estimatedRowHeight, estimatedHeaderHeight):
            "vertical:\(rowSpacing):\(estimatedRowHeight):\(estimatedHeaderHeight)"
        case let .custom(customLayout):
            "custom:\(customLayout.id)"
        }
    }

    /// `true` when the layout applies the caller's horizontal content insets as the
    /// compositional layout's section insets rather than the scroll view's `contentInset`.
    ///
    /// `.fractionalWidth(1)` is relative to the collection view bounds — NOT bounds minus
    /// `contentInset` — so applying horizontal margins via the scroll view's `contentInset`
    /// would make the content wider than the viewport and scroll sideways. Mirrors
    /// `ShopFeedCollectionView`, which puts its horizontal margins in the section insets.
    var appliesHorizontalContentInsetsInLayout: Bool {
        switch self {
        case .vertical:
            true
        case .custom:
            false
        }
    }
}

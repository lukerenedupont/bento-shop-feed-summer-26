import UIKit

protocol ShopScrollViewProxyIdentifiable {
    var shopScrollViewProxyID: AnyHashable? { get }
}

@MainActor
public protocol ShopScrollViewItemScrolling: AnyObject {
    @discardableResult
    func shopScrollToItem(
        id: AnyHashable,
        position: UICollectionView.ScrollPosition,
        animated: Bool
    ) -> Bool
}

@MainActor
public final class ShopScrollViewProxy: @unchecked Sendable {
    private weak var scrollView: UIScrollView?

    public init() {}

    /// The signed offset from the adjusted resting top, or `nil` while detached.
    /// Zero is the resting top; negative values are top overscroll.
    public var contentOffsetFromTop: CGFloat? {
        guard let scrollView else {
            return nil
        }

        return scrollView.contentOffset.y + scrollView.adjustedContentInset.top
    }

    public func scrollToTop(animated: Bool = true) {
        guard let scrollView else {
            return
        }

        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: -scrollView.adjustedContentInset.top),
            animated: animated
        )
    }

    @discardableResult
    public func scrollToItem<ID: Hashable>(
        id: ID,
        position: UICollectionView.ScrollPosition = .centeredVertically,
        animated: Bool = true
    ) -> Bool {
        guard let itemScroller = scrollView as? ShopScrollViewItemScrolling else {
            return false
        }

        return itemScroller.shopScrollToItem(
            id: AnyHashable(id),
            position: position,
            animated: animated
        )
    }

    public func attach(_ scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    public func detach(_ scrollView: UIScrollView) {
        if self.scrollView === scrollView {
            self.scrollView = nil
        }
    }
}

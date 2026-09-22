import UIKit
import ObjectiveC

/// Shared UIKit bridge for scroll views that need to participate in native
/// navigation/tab chrome behavior while hosted from SwiftUI.
public enum ShopScrollViewNavigationBridge {
    /// Registers `scrollView` as the content scroll view for the view controller
    /// the navigation bar actually manages (the navigation-managed ancestor of the
    /// scroll view's nearest hosting controller). UIKit then uses the real nested
    /// scroll view for large-title collapse, scroll-edge appearances, and adjusted
    /// insets — whether the scroll view is hosted via `UIViewRepresentable` or a
    /// nested `UIViewControllerRepresentable`.
    ///
    /// Pass the returned controller back on the next call so a changed host can
    /// be unregistered before the new one is registered.
    @discardableResult
    public static func register(
        scrollView: UIScrollView,
        replacing registeredViewController: UIViewController?
    ) -> UIViewController? {
        guard scrollView.window != nil,
              let nearestViewController = scrollView.shopNearestViewController else {
            return registeredViewController
        }

        // The navigation bar drives large-title collapse / scroll-edge effects from the
        // content scroll view of the view controller it directly manages (the pushed
        // screen), not from a nested child controller. A scroll view hosted via
        // `UIViewControllerRepresentable` (e.g. the feed collection controller) resolves
        // to its own child controller here, so bind to the navigation-managed ancestor
        // instead. Plain `UIViewRepresentable`-hosted lists already resolve to that same
        // controller, so this is a no-op for them.
        let candidates = [
            nearestViewController.shopNavigationManagedAncestor,
            nearestViewController.navigationController?.topViewController,
            nearestViewController,
        ]

        guard let viewController = candidates.compactMap({ $0 }).first(where: { candidate in
            guard let candidateView = candidate.viewIfLoaded,
                  candidateView.window === scrollView.window else {
                return false
            }

            return scrollView.isDescendant(of: candidateView)
        }) else {
            return registeredViewController
        }

        if registeredViewController === viewController,
           viewController.shopRegisteredContentScrollView === scrollView {
            return viewController
        }

        if registeredViewController !== viewController {
            registeredViewController?.setContentScrollView(nil, for: [.top, .bottom])
            registeredViewController?.shopRegisteredContentScrollView = nil
        }

        viewController.setContentScrollView(scrollView, for: [.top, .bottom])
        viewController.shopRegisteredContentScrollView = scrollView
        return viewController
    }

    /// Clears a prior content-scroll-view registration and returns `nil` so
    /// callers can reset their weak tracking property in one assignment.
    @discardableResult
    public static func unregister(from registeredViewController: UIViewController?) -> UIViewController? {
        registeredViewController?.setContentScrollView(nil, for: [.top, .bottom])
        registeredViewController?.shopRegisteredContentScrollView = nil
        return nil
    }
}

private final class ShopWeakScrollViewBox {
    weak var scrollView: UIScrollView?

    init(_ scrollView: UIScrollView?) {
        self.scrollView = scrollView
    }
}

private nonisolated(unsafe) var shopRegisteredContentScrollViewKey: UInt8 = 0

private extension UIViewController {
    var shopRegisteredContentScrollView: UIScrollView? {
        get {
            (objc_getAssociatedObject(self, &shopRegisteredContentScrollViewKey) as? ShopWeakScrollViewBox)?.scrollView
        }
        set {
            objc_setAssociatedObject(
                self,
                &shopRegisteredContentScrollViewKey,
                ShopWeakScrollViewBox(newValue),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

public extension UIScrollView {
    /// Keeps iOS 26's soft scroll-edge effects aligned with whether UIKit owns
    /// top/bottom inset adjustment for this scroll view.
    func shopUpdateScrollEdgeEffects(forcesTopEffectVisible: Bool = false) {
        guard #available(iOS 26.0, *) else {
            return
        }

        switch contentInsetAdjustmentBehavior {
        case .automatic, .always:
            topEdgeEffect.isHidden = false
            bottomEdgeEffect.isHidden = false
            topEdgeEffect.style = .soft
            bottomEdgeEffect.style = .soft
        default:
            topEdgeEffect.isHidden = !forcesTopEffectVisible
            if forcesTopEffectVisible {
                topEdgeEffect.style = .soft
            }
            bottomEdgeEffect.isHidden = true
        }
    }
}

private extension UIView {
    var shopNearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }

        return nil
    }
}

private extension UIViewController {
    /// The view controller managed directly by the nearest `UINavigationController`
    /// (i.e. whose navigation item drives the bar). Walks up the parent chain until it
    /// reaches a direct child of that navigation controller. Returns `nil` when the
    /// controller isn't hosted inside a navigation controller.
    var shopNavigationManagedAncestor: UIViewController? {
        guard let navigationController else { return nil }

        var candidate: UIViewController = self
        while let parent = candidate.parent, parent !== navigationController {
            candidate = parent
        }

        return candidate.parent === navigationController ? candidate : nil
    }
}

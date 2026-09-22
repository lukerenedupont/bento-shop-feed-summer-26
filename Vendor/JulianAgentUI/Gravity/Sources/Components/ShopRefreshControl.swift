import UIKit

/// `UIRefreshControl` with Shop's branded spinner installed inside the control itself.
///
/// UIKit still owns the pull threshold, refreshing content inset, and collapse animation. This class
/// only swaps the visible activity indicator.
@MainActor
public final class ShopRefreshControl: UIRefreshControl {
    private enum Metrics {
        static let spinnerSize = ShopSpinnerSize.medium.points
    }

    private let shopSpinnerView = ShopCoreAnimationSpinnerView()
    private var shopSpinnerColor = UIColor(GravityColor.textBrand)

    public override init() {
        super.init()
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        hideSystemActivityIndicators(in: self)
        updateShopSpinnerPresentation()
    }

    public override func beginRefreshing() {
        super.beginRefreshing()
        updateShopSpinnerPresentation()
    }

    public override func endRefreshing() {
        super.endRefreshing()
        updateShopSpinnerPresentation()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateShopSpinnerPresentation()
    }

    public func update(color: UIColor) {
        shopSpinnerColor = color
        shopSpinnerView.update(pointSize: Metrics.spinnerSize, color: color)
    }

    private func commonInit() {
        clipsToBounds = false
        tintColor = .clear
        installShopSpinner()
        hideSystemActivityIndicators(in: self)
    }

    private func installShopSpinner() {
        shopSpinnerView.isAccessibilityElement = false
        shopSpinnerView.isUserInteractionEnabled = false
        shopSpinnerView.translatesAutoresizingMaskIntoConstraints = false
        shopSpinnerView.update(pointSize: Metrics.spinnerSize, color: shopSpinnerColor)
        shopSpinnerView.setRevealWindow(.pull(pullDistance: 0))

        addSubview(shopSpinnerView)
        NSLayoutConstraint.activate([
            shopSpinnerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            shopSpinnerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            shopSpinnerView.widthAnchor.constraint(equalToConstant: Metrics.spinnerSize),
            shopSpinnerView.heightAnchor.constraint(equalToConstant: Metrics.spinnerSize),
        ])
    }

    private func hideSystemActivityIndicators(in view: UIView) {
        for subview in view.subviews {
            if subview is UIActivityIndicatorView {
                subview.isHidden = true
                subview.alpha = 0
            }

            hideSystemActivityIndicators(in: subview)
        }
    }

    private func updateShopSpinnerPresentation() {
        if isRefreshing {
            shopSpinnerView.alpha = 1
            shopSpinnerView.transform = .identity
            shopSpinnerView.startAnimating()
            return
        }

        let pullDistance = currentPullDistance()
        let scale = ShopRefreshIndicatorMetrics.scale(for: pullDistance)
        shopSpinnerView.alpha = ShopRefreshIndicatorMetrics.opacity(for: pullDistance)
        shopSpinnerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        shopSpinnerView.setRevealWindow(.pull(pullDistance: pullDistance))
    }

    private func currentPullDistance() -> CGFloat {
        guard let scrollView = superview as? UIScrollView else {
            return 0
        }

        return max(0, -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))
    }
}

import Gravity
import UIKit

/// Shared elevation for floating glass. Apply to the outer, unclipped view;
/// the glass and its content own their clipping independently.
enum ShopUIKitFloatingShadow {
    /// Match a real bounds morph instead of snapping the shadow to the final shape.
    @MainActor
    static func pathAnimation(for layer: CALayer, matching action: (any CAAction)?) -> CABasicAnimation? {
        guard let template = action as? CABasicAnimation,
              let animation = template.copy() as? CABasicAnimation else { return nil }
        animation.keyPath = "shadowPath"
        animation.fromValue = layer.presentation()?.shadowPath ?? layer.shadowPath
        animation.toValue = nil
        return animation
    }

    @MainActor
    static func apply(to view: UIView) {
        view.clipsToBounds = false
        view.layer.shadowOpacity = 1
        view.layer.shadowRadius = ShopAgentFloatingSurfaceMetrics.shadowRadius
        view.layer.shadowOffset = CGSize(width: 0, height: ShopAgentFloatingSurfaceMetrics.shadowYOffset)
    }

    @MainActor
    static func updatePath(of view: UIView, cornerRadius: CGFloat) {
        view.layer.shadowColor = UIColor(GravityColor.shadow300).resolvedColor(with: view.traitCollection).cgColor
        guard !view.bounds.isEmpty else { return }
        view.layer.shadowPath = UIBezierPath(roundedRect: view.bounds, cornerRadius: cornerRadius).cgPath
    }
}

import Gravity
import UIKit

/// Shared image treatment for the composer's collapsed thumbnail and attachment row.
@MainActor
final class ShopAgentComposerProductImageOverlay: UIView {
    init(on imageView: UIView) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(GravityColor.bgOverlayFixedDark04)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        isHidden = true
        imageView.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            topAnchor.constraint(equalTo: imageView.topAnchor),
            bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

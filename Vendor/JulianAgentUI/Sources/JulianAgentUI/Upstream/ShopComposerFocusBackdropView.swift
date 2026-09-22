import Gravity
import UIKit

/// The shared draft curtain: live background blur plus retained transition covers.
final class ShopComposerFocusBackdropView: UIView {
    // Keep the draft curtain light regardless of the underlying screen's appearance.
    private let draftBlurEffect = UIBlurEffect(style: .systemMaterial)
    private let blur = UIVisualEffectView(effect: nil)
    private let tintView = UIView()
    private let conversationCover = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        accessibilityIdentifier = "agent-draft-backdrop"
        blur.overrideUserInterfaceStyle = .light
        tintView.backgroundColor = UIColor(GravityColor.bgOverlayFixedLight10)
        conversationCover.backgroundColor = .white
        for child in [blur, tintView, conversationCover] {
            child.translatesAutoresizingMaskIntoConstraints = false
            addSubview(child)
            NSLayoutConstraint.activate([
                child.leadingAnchor.constraint(equalTo: leadingAnchor),
                child.trailingAnchor.constraint(equalTo: trailingAnchor),
                child.topAnchor.constraint(equalTo: topAnchor),
                child.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }
        setVisible(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Animate effects, never an effect view's (or its ancestor's) alpha. Fading
    /// the whole hierarchy forces offscreen compositing, which UIKit does not
    /// support for live visual effects.
    func setVisible(_ visible: Bool, obscuresBackground: Bool = false) {
        let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
        blur.effect = visible && !reduceTransparency ? draftBlurEffect : nil
        tintView.alpha = 0
        conversationCover.alpha = visible && (obscuresBackground || reduceTransparency) ? 1 : 0
    }
}

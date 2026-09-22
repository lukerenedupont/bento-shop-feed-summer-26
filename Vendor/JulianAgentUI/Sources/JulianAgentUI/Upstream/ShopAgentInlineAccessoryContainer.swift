import UIKit

/// Keeps one accessory view alive while it moves between scroll content and
/// the keyboard presentation. The empty inline slot keeps its measured height.
final class ShopAgentInlineAccessoryContainer: UIView {
    private(set) var contentView: (UIView & UIContentView)?
    private var inlineConstraints: [NSLayoutConstraint] = []
    private var measuredHeight: CGFloat = 0

    func update(configuration: any UIContentConfiguration) {
        if let contentView {
            contentView.configuration = configuration
        } else {
            contentView = configuration.makeContentView()
            returnContentInline()
        }
    }

    func fittingSize(width: CGFloat) -> CGSize {
        guard let contentView else { return .zero }
        if contentView.superview === self {
            measuredHeight = contentView.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
        }
        return CGSize(width: width, height: measuredHeight)
    }

    func releaseContent() -> UIView? {
        NSLayoutConstraint.deactivate(inlineConstraints)
        inlineConstraints = []
        return contentView
    }

    func returnContentInline() {
        guard let contentView, contentView.superview !== self else { return }
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        inlineConstraints = [
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
        NSLayoutConstraint.activate(inlineConstraints)
    }
}

import SwiftUI
import UIKit

@MainActor
final class ShopCollectionListHostingSupplementaryView<Content: View>: UICollectionReusableView {
    private var hostedContentView: (UIView & UIContentView)?

    static var reuseIdentifier: String {
        String(describing: Self.self)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostedContentView?.removeFromSuperview()
        hostedContentView = nil
        invalidateHostedContentSize()
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let fittingAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes ?? layoutAttributes
        let targetSize = CGSize(
            width: layoutAttributes.size.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let measuredSize = systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        guard measuredSize.height > 0 else {
            return fittingAttributes
        }

        fittingAttributes.size.width = layoutAttributes.size.width
        fittingAttributes.size.height = ceil(measuredSize.height)
        return fittingAttributes
    }

    func configure(content: Content) {
        let configuration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)

        if let hostedContentView {
            hostedContentView.configuration = configuration
        } else {
            let hostedContentView = configuration.makeContentView()
            hostedContentView.translatesAutoresizingMaskIntoConstraints = false
            hostedContentView.backgroundColor = .clear
            addSubview(hostedContentView)
            NSLayoutConstraint.activate([
                hostedContentView.topAnchor.constraint(equalTo: topAnchor),
                hostedContentView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hostedContentView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hostedContentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            self.hostedContentView = hostedContentView
        }

        invalidateHostedContentSize()
    }

    private func invalidateHostedContentSize() {
        invalidateIntrinsicContentSize()
        hostedContentView?.invalidateIntrinsicContentSize()
        hostedContentView?.setNeedsLayout()
        setNeedsLayout()
    }
}

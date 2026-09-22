import SwiftUI
import UIKit

@MainActor
final class ShopCollectionListHostingCell<Content: View>: UICollectionViewCell {
    private var hostingController: UIHostingController<Content>?
    private weak var hostingParentViewController: UIViewController?
    private var hostedItemID: AnyHashable?

    static var reuseIdentifier: String {
        String(describing: Self.self)
    }

    static func reuseIdentifier(for reuseKind: ShopCollectionListRowReuseKind) -> String {
        "\(reuseIdentifier).\(reuseKind.rawValue).\(reuseKind.hostingMode)"
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = false
        contentView.clipsToBounds = false
    }

    override var safeAreaInsets: UIEdgeInsets {
        .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            tearDownHostingController()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        backgroundConfiguration = .clear()
        alpha = 1
        hostingController?.view.alpha = 1
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let fittingAttributes = layoutAttributes.copy() as? UICollectionViewLayoutAttributes ?? layoutAttributes
        let targetSize = CGSize(
            width: layoutAttributes.size.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        let measuredSize = contentView.systemLayoutSizeFitting(
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

    func configure(
        content: Content,
        itemID: AnyHashable? = nil,
        hostingMode: ShopCollectionListRowReuseKind.HostingMode = .configuration,
        parentViewController: UIViewController? = nil
    ) {
        switch hostingMode {
        case .configuration:
            configureUsingHostingConfiguration(content: content)
        case .persistentHostingController:
            if let parentViewController {
                contentConfiguration = nil
                configureHostingController(
                    content: content,
                    itemID: itemID,
                    parentViewController: parentViewController
                )
            } else {
                configureUsingHostingConfiguration(content: content)
            }
        }

        backgroundConfiguration = .clear()
        invalidateHostedContentSize()
    }

    private func configureUsingHostingConfiguration(content: Content) {
        tearDownHostingController()
        contentConfiguration = UIHostingConfiguration {
            content
        }
        .margins(.all, 0)
    }

    private func configureHostingController(
        content: Content,
        itemID: AnyHashable?,
        parentViewController: UIViewController
    ) {
        if let hostingController, hostedItemID == itemID {
            hostingController.rootView = content
            if hostingParentViewController !== parentViewController {
                moveHostingController(hostingController, to: parentViewController)
            }
            return
        }

        tearDownHostingController()

        let hostingController = UIHostingController(rootView: content)
        hostingController.safeAreaRegions = []
        hostingController.sizingOptions = [.intrinsicContentSize]
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        parentViewController.addChild(hostingController)
        contentView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        hostingController.didMove(toParent: parentViewController)

        self.hostingController = hostingController
        hostingParentViewController = parentViewController
        hostedItemID = itemID
    }

    private func moveHostingController(
        _ hostingController: UIHostingController<Content>,
        to parentViewController: UIViewController
    ) {
        if hostingController.parent != nil {
            hostingController.willMove(toParent: nil)
            hostingController.removeFromParent()
        }

        parentViewController.addChild(hostingController)
        hostingController.didMove(toParent: parentViewController)
        hostingParentViewController = parentViewController
    }

    private func tearDownHostingController() {
        guard let hostingController else {
            hostingParentViewController = nil
            hostedItemID = nil
            return
        }

        if hostingController.parent != nil {
            hostingController.willMove(toParent: nil)
        }
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        self.hostingController = nil
        hostingParentViewController = nil
        hostedItemID = nil
    }

    private func invalidateHostedContentSize() {
        invalidateIntrinsicContentSize()
        contentView.invalidateIntrinsicContentSize()
        hostingController?.view.invalidateIntrinsicContentSize()
        contentView.setNeedsLayout()
        setNeedsLayout()
    }
}

import Gravity
import UIKit

final class ShopNavigationTitleStyleController: UIViewController {
    var style: GravityTextStyle = .posterXS

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        applyStyle()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        applyStyle()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // SwiftUI can replace the item's appearances when its toolbar updates.
        // Only write changed attributes, avoiding repeated navigation-bar layouts.
        applyStyle()
    }

    func applyStyle() {
        var ancestor = parent
        while let owner = ancestor {
            if let navigationController = owner.parent as? UINavigationController {
                let item = owner.navigationItem
                let bar = navigationController.navigationBar
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: style.scaledUIFont(for: traitCollection.preferredContentSizeCategory),
                    .kern: style.kerning,
                ]
                let standard = item.standardAppearance ?? bar.standardAppearance
                apply(attributes, to: item, at: \.standardAppearance, fallback: standard)
                apply(attributes, to: item, at: \.scrollEdgeAppearance,
                      fallback: bar.scrollEdgeAppearance ?? standard)
                apply(attributes, to: item, at: \.compactAppearance,
                      fallback: bar.compactAppearance ?? standard)
                apply(attributes, to: item, at: \.compactScrollEdgeAppearance,
                      fallback: bar.compactScrollEdgeAppearance ?? bar.compactAppearance ?? standard)
                return
            }
            ancestor = owner.parent
        }
    }

    private func apply(
        _ attributes: [NSAttributedString.Key: Any],
        to item: UINavigationItem,
        at keyPath: ReferenceWritableKeyPath<UINavigationItem, UINavigationBarAppearance?>,
        fallback: UINavigationBarAppearance
    ) {
        let appearance = item[keyPath: keyPath] ?? fallback
        let styledAttributes = appearance.largeTitleTextAttributes.merging(attributes) { _, style in style }
        guard !NSDictionary(dictionary: appearance.largeTitleTextAttributes).isEqual(to: styledAttributes) else {
            return
        }
        let styledAppearance = appearance.copy() as! UINavigationBarAppearance
        styledAppearance.largeTitleTextAttributes = styledAttributes
        item[keyPath: keyPath] = styledAppearance
    }
}

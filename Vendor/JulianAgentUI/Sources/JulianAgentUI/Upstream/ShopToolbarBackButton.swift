import Gravity
import SwiftUI
import UIKit

/// The shared top-leading system Back control.
/// The navigation owner supplies the action so chat collapse and route interceptors still run.
struct ShopToolbarBackButton: ToolbarContent {
    var isVisible = true
    let action: () -> Void

    var body: some ToolbarContent {
        if isVisible {
            ToolbarItem(id: "shop-toolbar-back", placement: .topBarLeading) {
                ShopToolbarBackControl(action: action)
            }
        }
    }
}

/// Dedicated Back control. Contextual lockups remain separate toolbar items.
struct ShopToolbarBackControl: View {
    @Environment(ShopCheckoutBlockingPresenter.self) private var checkoutBlockingPresenter: ShopCheckoutBlockingPresenter?
    let action: () -> Void

    // Give the system toolbar one intrinsically sized image, rather than a resizable SwiftUI
    // hierarchy that gets laid out again as search/streaming updates rebuild toolbar preferences.
    // UIKit then owns centering and the native glass button's insertion/removal transition.
    static let chevronImage: UIImage = {
        let size = CGSize(width: ShopIconSize.medium.points, height: ShopIconSize.medium.points)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIImage(named: GravityIconName.leftChevron.assetName, in: .gravityResources, compatibleWith: nil)?
                .draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate).imageFlippedForRightToLeftLayoutDirection()
    }()

    var body: some View {
        Button(action: action) {
            Image(uiImage: Self.chevronImage)
                // Keep the label box stable across toolbar updates. The system adds
                // its horizontal button insets, giving this a 44pt circular control.
                .frame(width: GravitySpacing.space32, height: GravitySpacing.space44)
        }
        .shopToolbarIconStyle()
        .accessibilityLabel(localizedString("Header.BackA11yLabel"))
        .accessibilityIdentifier("toolbar-back-button")
        .disabled(checkoutBlockingPresenter?.isActive == true)
    }
}

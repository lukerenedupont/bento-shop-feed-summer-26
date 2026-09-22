import Gravity
import SwiftUI
import UIKit

/// Applies Gravity typography to a screen's native large title. SwiftUI supplies
/// per-item appearances that take precedence over the app's UIAppearance defaults.
struct ShopNavigationTitleStyle: UIViewControllerRepresentable {
    let style: GravityTextStyle

    func makeUIViewController(context: Context) -> ShopNavigationTitleStyleController {
        ShopNavigationTitleStyleController()
    }

    func updateUIViewController(_ controller: ShopNavigationTitleStyleController, context: Context) {
        controller.style = style
        controller.applyStyle()
    }
}

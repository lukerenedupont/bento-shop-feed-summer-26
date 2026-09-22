import SwiftUI
import Gravity
import UIKit

struct ShopFeedQuickLinkPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.06 : 1)
            .animation(ShopMotion.press, value: configuration.isPressed)
    }
}


import SwiftUI
import UIKit

/// Supplies bindings and actions to the shell's composer; renders no navigation or input UI.
struct ShopBottomNavigationComposerSource: UIViewRepresentable {
    let navigation: ShopBottomNavigationConversation
    let composer: ShopAgentUIKitComposer

    func makeUIView(context: Context) -> ShopBottomNavigationComposerSourceView {
        ShopBottomNavigationComposerSourceView()
    }

    func updateUIView(_ view: ShopBottomNavigationComposerSourceView, context: Context) {
        if view.navigation !== navigation {
            view.disconnect()
            view.navigation = navigation
        }
        view.composer = composer
        navigation.composerSource = view
        navigation.controller?.updateComposer()
    }

    static func dismantleUIView(_ view: ShopBottomNavigationComposerSourceView, coordinator: ()) {
        view.disconnect()
    }
}

final class ShopBottomNavigationComposerSourceView: UIView {
    weak var navigation: ShopBottomNavigationConversation?
    var composer: ShopAgentUIKitComposer?

    func disconnect() {
        guard let navigation, navigation.composerSource === self else { return }
        navigation.composerSource = nil
        composer = nil
        navigation.controller?.updateComposer()
        self.navigation = nil
    }
}

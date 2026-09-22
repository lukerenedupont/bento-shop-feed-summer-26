import UIKit

/// Only a mounted placement may host the shared composer. Feed headers also create
/// offscreen instances for measurement; those must never replace its return destination.
final class ShopAgentInlineComposerContainer: UIView {
    private weak var navigation: ShopBottomNavigationConversation?

    func update(navigation: ShopBottomNavigationConversation) {
        if self.navigation !== navigation {
            disconnect()
            self.navigation = navigation
        }
        registerIfMounted()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            unregister()
        } else {
            registerIfMounted()
        }
    }

    func disconnect() {
        unregister()
        navigation = nil
    }

    private func registerIfMounted() {
        guard window != nil, let navigation,
              navigation.inlineComposerContainer !== self else { return }
        navigation.inlineComposerContainer = self
        navigation.controller?.updateComposer()
    }

    private func unregister() {
        guard let navigation, navigation.inlineComposerContainer === self else { return }
        navigation.inlineComposerContainer = nil
        navigation.controller?.updateComposer()
    }
}

import SwiftUI

/// Stable placement above the tab's navigation stack. Screen hosts supply state,
/// but pushing or popping a screen never moves the input's UIKit container.
struct ShopAgentComposerSessionOverlay: UIViewControllerRepresentable {
    let session: ShopAgentComposerSession

    func makeUIViewController(context: Context) -> ShopAgentComposerHostViewController {
        ShopAgentComposerHostViewController(session: session)
    }

    func updateUIViewController(_ controller: ShopAgentComposerHostViewController, context: Context) {
        session.setPresentationHost(controller)
    }

    static func dismantleUIViewController(_ controller: ShopAgentComposerHostViewController, coordinator: ()) {
        controller.disconnect()
    }
}

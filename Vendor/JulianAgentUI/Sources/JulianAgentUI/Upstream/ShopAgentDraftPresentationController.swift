import SwiftUI
import UIKit

/// One draft presentation, independent of the underlying screen and input.
/// The backdrop covers the source toolbar too; only the composer follows the keyboard.
final class ShopAgentDraftPresentationController: UIViewController {
    private let backdrop = ShopComposerFocusBackdropView()
    private var toolbarHost: UIHostingController<ShopAskPage>?
    private var animator: UIViewPropertyAnimator?
    private(set) var isPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isHidden = true
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func update(navigation: ShopBottomNavigationConversation?) {
        loadViewIfNeeded()
        let presented = navigation?.isDraftPresented == true
        if presented, let navigation {
            let page = ShopAskPage(
                onClose: { [weak navigation] in navigation?.closeAskPage() },
                onHistory: navigation.dockedAccessorySource?.onHistory
            )
            if let toolbarHost {
                toolbarHost.rootView = page
            } else {
                let host = UIHostingController(rootView: page)
                host.safeAreaRegions = .container
                host.view.backgroundColor = .clear
                host.view.alpha = 0
                addChild(host)
                host.view.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(host.view)
                NSLayoutConstraint.activate([
                    host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    host.view.topAnchor.constraint(equalTo: view.topAnchor),
                    host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                host.didMove(toParent: self)
                toolbarHost = host
            }
        }
        // The hosting controller survives the fade into a conversation. Reconcile
        // its interaction on every update, including reopening and same-state updates.
        toolbarHost?.view.isUserInteractionEnabled = presented
        guard presented != isPresented else { return }
        let transitionsToConversation = isPresented && !presented && navigation?.isConversationVisible == true
        isPresented = presented
        animator?.stopAnimation(true)
        view.isHidden = false
        view.isUserInteractionEnabled = presented
        view.layoutIfNeeded()
        if transitionsToConversation, !UIAccessibility.isReduceMotionEnabled {
            let obscure = UIViewPropertyAnimator(duration: 0.10, curve: .easeOut) { [weak self] in
                self?.backdrop.setVisible(true, obscuresBackground: true)
                self?.toolbarHost?.view.alpha = 0
            }
            obscure.addCompletion { [weak self] position in
                guard let self, position == .end, self.isPresented == false else { return }
                let reveal = UIViewPropertyAnimator(duration: 0.16, curve: .easeOut) { [weak self] in
                    self?.backdrop.setVisible(false)
                }
                reveal.addCompletion { [weak self] position in
                    guard let self, position == .end, self.isPresented == false else { return }
                    self.view.isHidden = true
                    self.animator = nil
                }
                self.animator = reveal
                reveal.startAnimation()
            }
            animator = obscure
            obscure.startAnimation()
            return
        }
        let animation = UIViewPropertyAnimator(
            duration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25, curve: .easeOut
        ) { [weak self] in
            self?.backdrop.setVisible(presented)
            self?.toolbarHost?.view.alpha = presented ? 1 : 0
        }
        animation.addCompletion { [weak self] position in
            guard let self, position == .end, self.isPresented == presented else { return }
            self.view.isHidden = !presented
            self.animator = nil
        }
        animator = animation
        animation.startAnimation()
    }
}

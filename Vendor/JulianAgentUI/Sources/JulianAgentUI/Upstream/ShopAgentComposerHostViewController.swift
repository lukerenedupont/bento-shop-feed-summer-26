import UIKit

/// Supplies a screen's composer state to the session. The shell's stable overlay
/// owns placement; standalone screens and presented sheets can also host the input here.
final class ShopAgentComposerHostViewController: UIViewController {
    private let session: ShopAgentComposerSession
    private(set) var composer: ShopAgentUIKitComposer?
    private(set) var priority = ShopAgentComposerPriority.landing
    private(set) var isEnabled = true
    private(set) var isVisible = false
    private var composerConstraints: [NSLayoutConstraint] = []

    init(session: ShopAgentComposerSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = ShopAgentComposerHostPassthroughView()
        view.backgroundColor = .clear
        view.clipsToBounds = false
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        isVisible = true
        session.refresh(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        session.refresh(self)
    }

    func update(composer: ShopAgentUIKitComposer, priority: ShopAgentComposerPriority, isEnabled: Bool) {
        self.composer = composer
        self.priority = priority
        self.isEnabled = isEnabled
        session.refresh(self)
    }

    func disconnect() {
        isVisible = false
        composer = nil
        session.remove(self)
    }

    func attach(_ controller: ShopAgentUIKitComposerViewController) {
        addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controller.view)
        composerConstraints = [
            controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: view.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        NSLayoutConstraint.activate(composerConstraints)
        controller.didMove(toParent: self)
        view.layoutIfNeeded()
    }

    func detach(_ controller: ShopAgentUIKitComposerViewController) {
        guard controller.parent === self else { return }
        controller.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(composerConstraints)
        composerConstraints = []
        controller.view.removeFromSuperview()
        controller.removeFromParent()
    }
}

private final class ShopAgentComposerHostPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

import SwiftUI
import UIKit

extension EnvironmentValues {
    @Entry var shopAgentComposerSession: ShopAgentComposerSession?
    @Entry var shopAgentComposerPriority = ShopAgentComposerPriority.landing
    @Entry var shopAgentComposerIsEnabled = true
}

enum ShopAgentComposerPriority: Int {
    case landing
    case conversation
    case expanded
}

/// One live input/material per shell, including the sheet above it. Screens supply bindings;
/// only the frontmost visible host can apply them. Search and pushed conversations share
/// a stable shell placement, so navigation never reparents their input or steals focus.
@MainActor
final class ShopAgentComposerSession {
    private(set) lazy var controller = ShopAgentUIKitComposerViewController()
    private let hosts = NSHashTable<ShopAgentComposerHostViewController>.weakObjects()
    private weak var activeHost: ShopAgentComposerHostViewController?
    private weak var presentationHost: ShopAgentComposerHostViewController?

    func setPresentationHost(_ host: ShopAgentComposerHostViewController) {
        guard presentationHost !== host else { return }
        presentationHost = host
        reconcile()
    }

    func refresh(_ host: ShopAgentComposerHostViewController) {
        hosts.add(host)
        reconcile()
    }

    func remove(_ host: ShopAgentComposerHostViewController) {
        hosts.remove(host)
        if presentationHost === host { presentationHost = nil }
        reconcile()
    }

    private func reconcile() {
        let eligible = hosts.allObjects.filter { $0.isVisible && $0.isEnabled && $0.composer != nil }
        // Keep the current host on ties; background updates aren't navigation intent.
        let next = eligible.max {
            if $0.priority != $1.priority { return $0.priority.rawValue < $1.priority.rawValue }
            return $0 !== activeHost && $1 === activeHost
        }
        guard let next else {
            guard controller.parent != nil else { return }
            controller.beginHostChange()
            // Keep the stable placement intact through the brief gap between
            // an outgoing source disappearing and Search becoming active.
            if controller.parent !== presentationHost {
                (controller.parent as? ShopAgentComposerHostViewController)?.detach(controller)
            }
            controller.view.isHidden = true
            activeHost = nil
            controller.disconnect()
            controller.endHostChange()
            return
        }
        // A presented sheet still needs its own placement above the shell.
        let placement = next.priority == .expanded ? next : (presentationHost ?? next)
        if controller.parent !== placement {
            controller.beginHostChange()
            (controller.parent as? ShopAgentComposerHostViewController)?.detach(controller)
            placement.attach(controller)
            controller.view.isHidden = false
            next.composer?.configure(controller)
            controller.endHostChange()
        } else {
            controller.view.isHidden = false
            next.composer?.configure(controller)
        }
        activeHost = next
    }
}

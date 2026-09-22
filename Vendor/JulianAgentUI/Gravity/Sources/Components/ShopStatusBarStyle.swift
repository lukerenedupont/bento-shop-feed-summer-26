import SwiftUI
import UIKit

public extension View {
    /// Explicitly controls the status bar glyph color (time, battery, signal)
    /// while this view is visible.
    ///
    /// The app keeps the status bar under system control by default so iOS can
    /// adapt it to the content beneath it (on iOS 26 this is the same
    /// luminance-driven adaptation navigation bar titles get). Use this
    /// modifier only for surfaces whose backdrop the system cannot infer:
    /// custom chrome over hero media, full-screen video, or brand-driven
    /// backdrops delivered as data (e.g. a merchant's `statusBarStyle`).
    ///
    /// Passing `nil` releases the override and returns control to the system.
    /// Overrides are scoped to visibility: they apply on appear and are
    /// released on disappear. When several visible views declare a style, the
    /// most recently appeared one wins.
    func shopStatusBarStyle(_ style: UIStatusBarStyle?) -> some View {
        modifier(ShopStatusBarStyleModifier(style: style))
    }
}

private struct ShopStatusBarStyleModifier: ViewModifier {
    let style: UIStatusBarStyle?

    @State private var token = UUID()
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isVisible = true
                ShopStatusBarStyleCoordinator.shared.set(style, for: token)
            }
            .onChange(of: style) { _, newStyle in
                // Covered views (e.g. a screen below a pushed one) still
                // re-evaluate; only visible views may own the status bar.
                guard isVisible else { return }
                ShopStatusBarStyleCoordinator.shared.set(newStyle, for: token)
            }
            .onDisappear {
                isVisible = false
                ShopStatusBarStyleCoordinator.shared.remove(token)
            }
    }
}

/// Arbitrates status-bar style overrides and applies the winning one through a
/// transparent, untouchable window whose root view controller vends
/// `preferredStatusBarStyle`.
///
/// UIKit derives status bar appearance from the frontmost full-screen window,
/// so this works identically under navigation pushes, sheets, and full-screen
/// covers — without depending on SwiftUI's internal hosting-controller
/// behavior. While no override is active the window stays hidden and status
/// bar control falls back to the app's main window (`.default` style), which
/// preserves the system's automatic content-based adaptation.
@MainActor
final class ShopStatusBarStyleCoordinator {
    static let shared = ShopStatusBarStyleCoordinator()

    private struct Override {
        let token: UUID
        var style: UIStatusBarStyle?
    }

    private var overrides: [Override] = []
    private(set) var window: ShopStatusBarStyleWindow?

    func set(_ style: UIStatusBarStyle?, for token: UUID) {
        if let index = overrides.firstIndex(where: { $0.token == token }) {
            overrides[index].style = style
        } else {
            overrides.append(Override(token: token, style: style))
        }
        apply()
    }

    func remove(_ token: UUID) {
        overrides.removeAll { $0.token == token }
        apply()
    }

    private func apply() {
        guard let style = overrides.last(where: { $0.style != nil })?.style else {
            window?.isHidden = true
            return
        }

        guard let window = resolvedWindow() else { return }
        window.statusBarStyle = style
        window.isHidden = false
    }

    private func resolvedWindow() -> ShopStatusBarStyleWindow? {
        if let window, window.windowScene != nil {
            return window
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return nil
        }

        let window = ShopStatusBarStyleWindow(windowScene: scene)
        self.window = window
        return window
    }
}

/// Sits at `.statusBar` level: above the app's content window (so an active
/// override wins over pushed/presented surfaces), below the hard-upgrade
/// takeover window (`.alert + 1`), which also suppresses and restores this
/// window like every other app window while it is presented.
final class ShopStatusBarStyleWindow: UIWindow {
    private let styleViewController = ShopStatusBarStyleViewController()

    var statusBarStyle: UIStatusBarStyle {
        get { styleViewController.statusBarStyle }
        set { styleViewController.statusBarStyle = newValue }
    }

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .statusBar
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        accessibilityElementsHidden = true
        rootViewController = styleViewController
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

private final class ShopStatusBarStyleViewController: UIViewController {
    var statusBarStyle: UIStatusBarStyle = .default {
        didSet {
            guard statusBarStyle != oldValue else { return }
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        statusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isOpaque = false
    }
}

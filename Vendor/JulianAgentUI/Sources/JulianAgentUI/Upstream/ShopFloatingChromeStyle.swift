import Gravity
import SwiftUI
import UIKit

// Floating chrome intentionally owns a small, private style layer while Gravity lacks
// nav-specific chrome tokens. Prefer Gravity semantic colors first; keep bespoke motion,
// shadow, and glass constants local to app shell chrome so they can collapse into tokens later.
enum ShopFloatingChromeMetrics {
    static let buttonSize: CGFloat = 56
    static let transitionOffset: CGFloat = 40
    static let hiddenBlurRadius: CGFloat = 2.5

    /// Tint for `ShopGlassMaterial.clear` surfaces. The clear sandwich derives its
    /// translucency from its own layer opacities, so it needs an opaque tint — a
    /// pre-faded overlay token would double-dip and read too thin. Matches RN floating
    /// chrome, which passes the adaptive `theme.colors['bg-fill']` to every
    /// `TintedGlassBox` (`FloatingBottomTabBar.tsx`, `QuickLinkWrapper.tsx:129`).
    static let clearGlassTint = GravityColor.bgFill
}

enum ShopFloatingChromeShadowLevel {
    case standard
    case subtle
}

private struct ShopFloatingChromeShadowModifier: ViewModifier {
    let level: ShopFloatingChromeShadowLevel

    func body(content: Content) -> some View {
        switch level {
        case .standard:
            content
                .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
        case .subtle:
            content
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
}

extension View {
    func shopFloatingChromeShadow(_ level: ShopFloatingChromeShadowLevel = .standard) -> some View {
        modifier(ShopFloatingChromeShadowModifier(level: level))
    }
}

struct ShopFloatingChromePressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.06 : 1)
            .animation(ShopMotion.press, value: configuration.isPressed)
    }
}

struct ShopFloatingChromeLargeContentLabel: View {
    let icon: GravityIconName
    let title: String

    var body: some View {
        SwiftUI.Label {
            ShopText(title, style: .bodyLargeBold)
        } icon: {
            ShopIcon(icon, size: .xLarge, color: GravityColor.text)
        }
        .labelStyle(.titleAndIcon)
    }
}

extension View {
    func shopFloatingChromeLargeContentViewer(
        icon: GravityIconName,
        title: String
    ) -> some View {
        accessibilityShowsLargeContentViewer {
            ShopFloatingChromeLargeContentLabel(
                icon: icon,
                title: title
            )
        }
    }
}

struct ShopFloatingChromeBackground: View {
    var body: some View {
        ShopGlassCircleBackground(
            tint: ShopFloatingChromeMetrics.clearGlassTint,
            isInteractive: true,
            material: .clear
        )
        .clipShape(Circle())
        .shopFloatingChromeShadow()
    }
}

enum ShopRollingDirection {
    // Mirrors RN Rolling direction semantics: this is the hidden offset side.
    // `.right` appears by sliding left into place; `.left` appears by sliding right.
    case right
    case left
    case up
}

/// Shared UIKit glass primitives for the composer and floating navigation chrome.
/// `UIButton.Configuration.glass()` supplies the native interactive/mushy press response.
@MainActor
final class ShopUIKitGlassSurfaceView: UIView {
    private let fixedCornerRadius: CGFloat?
    private let glassView: UIVisualEffectView
    private let hasFloatingShadow: Bool

    var contentView: UIView { glassView.contentView }

    init(interactive: Bool, cornerRadius: CGFloat? = nil, hasFloatingShadow: Bool = false) {
        fixedCornerRadius = cornerRadius
        self.hasFloatingShadow = hasFloatingShadow
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: .regular)
            glass.isInteractive = interactive
            glassView = UIVisualEffectView(effect: glass)
        } else {
            glassView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        super.init(frame: .zero)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.clipsToBounds = true
        glassView.layer.cornerCurve = .continuous
        if #available(iOS 26.0, *) {
            // Declare the material's shape so native menu transitions restore rounded glass,
            // rather than waiting for a layer radius to be reapplied during layout.
            glassView.cornerConfiguration = cornerRadius.map {
                .uniformCorners(radius: .fixed(Double($0)))
            } ?? .capsule()
        }
        if #available(iOS 26.0, *), cornerRadius != nil {
            // Give resizing glass an explicit rendering container, including room
            // for its shadow. The glass surface and hit target keep their original
            // bounds; only the effect's drawing area extends beyond them.
            let container = UIVisualEffectView(effect: UIGlassContainerEffect())
            container.translatesAutoresizingMaskIntoConstraints = false
            container.clipsToBounds = false
            addSubview(container)
            let overflow: CGFloat = 48
            NSLayoutConstraint.activate([
                container.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -overflow),
                container.trailingAnchor.constraint(equalTo: trailingAnchor, constant: overflow),
                container.topAnchor.constraint(equalTo: topAnchor, constant: -overflow),
                container.bottomAnchor.constraint(equalTo: bottomAnchor, constant: overflow),
            ])
            container.contentView.addSubview(glassView)
        } else {
            addSubview(glassView)
        }
        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if hasFloatingShadow { ShopUIKitFloatingShadow.apply(to: self) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func action(for layer: CALayer, forKey event: String) -> (any CAAction)? {
        if event == "shadowPath", let animation = ShopUIKitFloatingShadow.pathAnimation(
            for: layer, matching: super.action(for: layer, forKey: "backgroundColor")
        ) {
            return animation
        }
        return super.action(for: layer, forKey: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = fixedCornerRadius ?? bounds.height / 2
        if #unavailable(iOS 26.0) {
            glassView.layer.cornerRadius = radius
        }
        if hasFloatingShadow { ShopUIKitFloatingShadow.updatePath(of: self, cornerRadius: radius) }
    }
}

@MainActor
final class ShopUIKitGlassButton: UIButton {
    private var fallbackEffectView: UIVisualEffectView?

    init() {
        super.init(frame: .zero)
        ShopUIKitFloatingShadow.apply(to: self)
        layer.cornerCurve = .continuous

        if #available(iOS 26.0, *) {
            var configuration = UIButton.Configuration.glass()
            configuration.contentInsets = .zero
            self.configuration = configuration
        } else {
            let effect = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
            effect.translatesAutoresizingMaskIntoConstraints = false
            effect.isUserInteractionEnabled = false
            effect.clipsToBounds = true
            effect.layer.cornerCurve = .continuous
            insertSubview(effect, at: 0)
            NSLayoutConstraint.activate([
                effect.leadingAnchor.constraint(equalTo: leadingAnchor),
                effect.trailingAnchor.constraint(equalTo: trailingAnchor),
                effect.topAnchor.constraint(equalTo: topAnchor),
                effect.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            fallbackEffectView = effect
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        fallbackEffectView?.layer.cornerRadius = layer.cornerRadius
        ShopUIKitFloatingShadow.updatePath(of: self, cornerRadius: layer.cornerRadius)
    }

    func setGlassImage(_ image: UIImage?) {
        if #available(iOS 26.0, *) {
            var updatedConfiguration = configuration ?? .glass()
            updatedConfiguration.image = image
            configuration = updatedConfiguration
        } else {
            setImage(image, for: .normal)
        }
    }

    func setGlassTint(_ color: UIColor, prominent: Bool = false) {
        if #available(iOS 26.0, *) {
            let existingImage = configuration?.image
            var updatedConfiguration: UIButton.Configuration = prominent ? .prominentGlass() : .glass()
            updatedConfiguration.contentInsets = .zero
            updatedConfiguration.image = existingImage
            updatedConfiguration.baseBackgroundColor = color
            configuration = updatedConfiguration
        } else {
            fallbackEffectView?.isHidden = prominent
            backgroundColor = prominent ? color : color.withAlphaComponent(0.86)
        }
    }
}

struct ShopRollingVisibility<Content: View>: View {
    let showing: Bool
    let direction: ShopRollingDirection
    let content: Content

    @State private var progress: CGFloat

    init(
        showing: Bool,
        direction: ShopRollingDirection = .left,
        @ViewBuilder content: () -> Content
    ) {
        self.showing = showing
        self.direction = direction
        self.content = content()
        _progress = State(initialValue: showing ? 1 : 0)
    }

    var body: some View {
        content
            .opacity(progress)
            .blur(radius: blurRadius)
            .scaleEffect(scale, anchor: scaleAnchor)
            .offset(x: horizontalOffset, y: verticalOffset)
            .onAppear {
                progress = showing ? 1 : 0
            }
            .onChange(of: showing) { _, newValue in
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 366, damping: 33, initialVelocity: 0)) {
                    progress = newValue ? 1 : 0
                }
            }
    }

    private var horizontalOffset: CGFloat {
        guard direction != .up else { return 0 }
        let hiddenOffset = direction == .right
            ? ShopFloatingChromeMetrics.transitionOffset
            : -ShopFloatingChromeMetrics.transitionOffset
        return interpolate(from: hiddenOffset, to: 0)
    }

    private var verticalOffset: CGFloat {
        guard direction == .up else { return 0 }
        return interpolate(from: ShopFloatingChromeMetrics.transitionOffset, to: 0)
    }

    private var blurRadius: CGFloat {
        interpolate(from: ShopFloatingChromeMetrics.hiddenBlurRadius, to: 0)
    }

    private var scale: CGFloat {
        interpolate(from: 0.5, to: 1)
    }

    private var scaleAnchor: UnitPoint {
        switch direction {
        case .right:
            return .trailing
        case .left:
            return .leading
        case .up:
            return .bottom
        }
    }

    private func interpolate(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

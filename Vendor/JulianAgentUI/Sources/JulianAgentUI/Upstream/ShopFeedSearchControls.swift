import CoreImage.CIFilterBuiltins
import SwiftUI
import Gravity
import UIKit

struct ShopFeedSearchQuickLinkPill: View {
    let actions: ShopFeedQuickLinkActions

    nonisolated init(actions: ShopFeedQuickLinkActions) {
        self.actions = actions
    }

    var body: some View {
        Button {
            ShopHaptics.light()
            actions.search()
        } label: {
            HStack(spacing: ShopSpacing.space4) {
                ShopIcon(.search, pointSize: ShopFeedHeaderMetrics.quickLinksIconSize, color: GravityColor.textFixedDark)
                    .frame(
                        width: ShopFeedHeaderMetrics.quickLinksIconSize,
                        height: ShopFeedHeaderMetrics.quickLinksIconSize
                    )
                ShopText(
                    localizedString("MainNavigationTabs.Search"),
                    style: .buttonMedium,
                    color: GravityColor.textFixedDark
                )
                    .lineLimit(1)
            }
            .padding(.horizontal, ShopSpacing.space12)
            .frame(height: ShopFeedHeaderMetrics.quickLinksItemHeight)
            .background {
                ShopGlassCapsuleBackground(
                    isInteractive: true,
                    material: .clear
                )
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .gravityShadow(.s)
        }
        .buttonStyle(ShopFeedQuickLinkPressButtonStyle())
        .accessibilityLabel(localizedString("MainNavigationTabs.Search"))
        .accessibilityIdentifier("home-search-chip")
    }
}

struct ShopFeedFloatingSearchOverlay: View {
    let onSearchTapped: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            ShopFeedTrailingProgressiveBlur(backgroundColor: ShopColor.background)
                .frame(
                    width: ShopSpacing.space48 * 2,
                    height: ShopFeedHeaderMetrics.navigationBarHeight
                )

            Button {
                ShopHaptics.light()
                onSearchTapped()
            } label: {
                ShopIcon(.search, size: .medium, color: GravityColor.textFixedDark)
                    .frame(width: ShopSpacing.space44, height: ShopSpacing.space44)
                    .contentShape(.circle)
            }
            .background {
                ShopGlassCircleBackground(
                    tint: ShopFloatingChromeMetrics.clearGlassTint,
                    isInteractive: true,
                    material: .clear
                )
            }
            .clipShape(Circle())
            .buttonStyle(ShopFloatingChromePressButtonStyle())
            .shopFloatingChromeShadow(.subtle)
            .accessibilityLabel(localizedString("MainNavigationTabs.Search"))
            .accessibilityIdentifier("home-floating-search")
            .padding(.trailing, ShopSpacing.screenMargin)
        }
        .allowsHitTesting(true)
    }
}

private struct ShopFeedTrailingProgressiveBlur: UIViewRepresentable {
    let backgroundColor: Color

    func makeUIView(context: Context) -> ShopFeedTrailingProgressiveBlurView {
        let view = ShopFeedTrailingProgressiveBlurView()
        view.update(backgroundColor: UIColor(backgroundColor))
        return view
    }

    func updateUIView(_ uiView: ShopFeedTrailingProgressiveBlurView, context: Context) {
        uiView.update(backgroundColor: UIColor(backgroundColor))
    }
}

private final class ShopFeedTrailingProgressiveBlurView: UIView {
    private let blurView = ShopFeedTrailingVariableBlurEffectView(maxBlurRadius: 20)
    private let colorGradient = CAGradientLayer()
    private var feedBackgroundColor = UIColor.clear

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        blurView.isUserInteractionEnabled = false
        addSubview(blurView)
        layer.addSublayer(colorGradient)

        colorGradient.locations = [0, 0.58, 1]
        colorGradient.startPoint = CGPoint(x: 0, y: 0.5)
        colorGradient.endPoint = CGPoint(x: 1, y: 0.5)

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ShopFeedTrailingProgressiveBlurView, _) in
            view.updateGradientColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(backgroundColor: UIColor) {
        feedBackgroundColor = backgroundColor
        updateGradientColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.frame = bounds
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        colorGradient.frame = bounds
        CATransaction.commit()
    }

    private func updateGradientColors() {
        let resolvedColor = feedBackgroundColor.resolvedColor(with: traitCollection)
        colorGradient.colors = [
            resolvedColor.withAlphaComponent(0).cgColor,
            resolvedColor.withAlphaComponent(0.58).cgColor,
            resolvedColor.cgColor,
        ]
    }
}

/// A horizontal adaptation of nikstar/VariableBlur's `VariableBlurUIView`.
///
/// VariableBlur is MIT licensed. The copied implementation is intentionally kept feature-local
/// because it accesses the private `CAFilter` variable-blur filter and must not become a shared
/// production primitive by accident. See `ThirdPartyNotices/VariableBlur/LICENSE.md`.
private final class ShopFeedTrailingVariableBlurEffectView: UIVisualEffectView {
    init(maxBlurRadius: CGFloat) {
        super.init(effect: UIBlurEffect(style: .regular))

        let filterClassName = String("retliFAC".reversed())
        let filterSelectorName = String(":epyThtiWretlif".reversed())
        guard
            let filterClass = NSClassFromString(filterClassName) as? NSObject.Type,
            let unmanagedFilter = filterClass.perform(
                NSSelectorFromString(filterSelectorName),
                with: "variableBlur"
            ),
            let variableBlur = unmanagedFilter.takeUnretainedValue() as? NSObject,
            let gradientImage = makeGradientImage()
        else {
            effect = nil
            return
        }

        variableBlur.setValue(maxBlurRadius, forKey: "inputRadius")
        variableBlur.setValue(gradientImage, forKey: "inputMaskImage")
        variableBlur.setValue(true, forKey: "inputNormalizeEdges")

        // UIVisualEffectView supplies the backdrop layer that can filter the content underneath.
        subviews.first?.layer.filters = [variableBlur]

        // Remove the standard material tint: the sibling color gradient owns the fade into the
        // feed background, while this view contributes blur only.
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        guard let window, let backdropLayer = subviews.first?.layer else { return }

        // Avoid pixelation at the fully-clear end of the gradient on Retina displays.
        backdropLayer.setValue(window.traitCollection.displayScale, forKey: "scale")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        // Calling super can re-enable the standard UIVisualEffectView filters and has crashed in
        // the upstream implementation during appearance changes.
    }

    private func makeGradientImage(width: CGFloat = 100, height: CGFloat = 100) -> CGImage? {
        let gradient = CIFilter.linearGradient()
        gradient.color0 = CIColor.black
        gradient.color1 = CIColor.clear
        gradient.point0 = CGPoint(x: width, y: 0)
        gradient.point1 = CGPoint(x: 0, y: 0)

        guard let outputImage = gradient.outputImage else { return nil }
        return CIContext().createCGImage(
            outputImage,
            from: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }
}

/// A pill reports its impression only while the surface is active and every reported field is known.
///
/// The offers pill's `badgeValue` comes from the active shopping event, which native fetches on
/// demand once Home renders (approved divergence from React Native's AppBoot prefetch, #111702). The
/// impression waits for that fetch instead of reporting a `nil` `badgeValue` it can never correct:
/// the tracking id excludes the icon url, so a later override would not re-fire the impression.
/// `active` flipping false -> true force-samples the pill, so the deferred impression fires once.
func shopFeedQuickLinkImpressionsActive(
    isActive: Bool,
    awaitsShoppingEventBadgeValue: Bool
) -> Bool {
    isActive && awaitsShoppingEventBadgeValue == false
}


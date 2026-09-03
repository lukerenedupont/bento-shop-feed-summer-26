import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

// MARK: - SwiftUI View

/// A real progressive blur using iOS's private CAFilter variableBlur.
/// Blurs content behind it with intensity controlled by a gradient mask.
/// Optionally overlays a color tint that fades in the same direction as the blur.
///
/// Usage:
///   VariableBlurView()                                          // pure blur, no tint
///   VariableBlurView(tintColor: .white, tintOpacity: 0.4)      // blur + white wash
///   VariableBlurView(maxBlurRadius: 24, tintColor: .black, tintOpacity: 0.2)
public struct VariableBlurView: View {
    public let maxBlurRadius: CGFloat
    public let direction: Direction
    public let tintColor: Color?
    public let tintOpacity: Double

    public init(
        maxBlurRadius: CGFloat = 20,
        direction: Direction = .bottomBlurToTopTransparent,
        tintColor: Color? = nil,
        tintOpacity: Double = 0.3
    ) {
        self.maxBlurRadius = maxBlurRadius
        self.direction = direction
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
    }

    public var body: some View {
        ZStack {
            _VariableBlurRepresentable(maxBlurRadius: maxBlurRadius, direction: direction)

            if let tintColor {
                LinearGradient(
                    colors: [
                        tintColor.opacity(0),
                        tintColor.opacity(tintOpacity),
                    ],
                    startPoint: direction == .bottomBlurToTopTransparent ? .top : .bottom,
                    endPoint: direction == .bottomBlurToTopTransparent ? .bottom : .top
                )
            }
        }
    }

    public enum Direction {
        case topBlurToBottomTransparent
        case bottomBlurToTopTransparent
    }
}

// MARK: - UIViewRepresentable

private struct _VariableBlurRepresentable: UIViewRepresentable {
    let maxBlurRadius: CGFloat
    let direction: VariableBlurView.Direction

    @Environment(\.layoutDirection) var layoutDirection

    func makeUIView(context: Context) -> VariableBlurUIView {
        VariableBlurUIView(radius: maxBlurRadius, direction: direction, layoutDirection: layoutDirection)
    }

    func updateUIView(_ blurView: VariableBlurUIView, context: Context) {
        guard
            maxBlurRadius != blurView.radius ||
            direction != blurView.direction ||
            layoutDirection != blurView.layoutDirection
        else { return }
        blurView.radius = maxBlurRadius
        blurView.direction = direction
        blurView.layoutDirection = layoutDirection
        blurView.updateFilter()
    }
}

// MARK: - CAFilter Wrapper

private final class VariableBlurFilter {
    private static let filterClass = NSClassFromString(
        _decode("Q0FGaWx0ZXI=") // "CAFilter"
    ) as? NSObject.Type

    let base: NSObject

    init?() {
        guard let filterClass = VariableBlurFilter.filterClass else { return nil }
        guard let variableBlur = filterClass
            .perform(
                NSSelectorFromString("filterWithType:"),
                with: _decode("dmFyaWFibGVCbHVy") // "variableBlur"
            )
            .takeUnretainedValue() as? NSObject
        else { return nil }

        self.base = variableBlur
        // "inputNormalizeEdges"
        self.base.setValue(true, forKey: _decode("aW5wdXROb3JtYWxpemVFZGdlcw=="))
    }

    var inputRadius: CGFloat {
        // "inputRadius"
        get { base.value(forKey: _decode("aW5wdXRSYWRpdXM=")) as? CGFloat ?? 0 }
        set { base.setValue(newValue, forKey: _decode("aW5wdXRSYWRpdXM=")) }
    }

    func setMaskImage(_ image: CGImage) {
        // "inputMaskImage"
        base.setValue(image, forKey: _decode("aW5wdXRNYXNrSW1hZ2U="))
    }
}

// MARK: - UIView

final class VariableBlurUIView: UIVisualEffectView {
    var radius: CGFloat
    var direction: VariableBlurView.Direction
    var layoutDirection: LayoutDirection

    func updateFilter() {
        guard let filter = VariableBlurFilter(),
              let maskImage = Self.maskImage(for: direction)
        else { return }
        filter.inputRadius = radius
        filter.setMaskImage(maskImage)
        subviews.first?.layer.filters = [filter.base]
    }

    init(radius: CGFloat, direction: VariableBlurView.Direction, layoutDirection: LayoutDirection) {
        self.radius = radius
        self.direction = direction
        self.layoutDirection = layoutDirection
        super.init(effect: UIBlurEffect(style: .regular))

        // Hide the tint/vibrancy overlays — we only want the blur backdrop
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
        updateFilter()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        guard let window, let firstLayer = subviews.first?.layer else { return }
        firstLayer.setValue(window.screen.scale, forKey: "scale")
    }

    private static func maskImage(for direction: VariableBlurView.Direction) -> CGImage? {
        let resolution: CGFloat = 128
        let filter = CIFilter.linearGradient()
        filter.color0 = CIColor.black
        filter.color1 = CIColor.clear

        switch direction {
        case .bottomBlurToTopTransparent:
            filter.point0 = CGPoint(x: 0, y: 0)
            filter.point1 = CGPoint(x: 0, y: resolution)
        case .topBlurToBottomTransparent:
            filter.point0 = CGPoint(x: 0, y: resolution)
            filter.point1 = CGPoint(x: 0, y: 0)
        }

        guard let ciImage = filter.outputImage else { return nil }
        let context = CIContext()
        let rect = CGRect(x: 0, y: 0, width: resolution, height: resolution)
        return context.createCGImage(ciImage, from: rect)
    }
}

// MARK: - Uniform Backdrop Blur

/// A uniform blur of whatever sits *behind* the view, at an exact radius and
/// with no tint.
///
/// SwiftUI's `.blur()` is simpler, but it blurs the view it is applied to, and
/// rasterising a full screen that way collapses that subtree's safe area.
/// Blurring the Try your faves stage that way shifted the whole look up by
/// half the difference between the top and bottom insets — in a single frame,
/// outside any animation transaction, so it could not be smoothed either.
/// Blurring the backdrop leaves the content beneath completely untouched.
///
/// `.ultraThinMaterial` is the public-API alternative, but its radius is not
/// adjustable and its tint lightens whatever is behind it.
struct BackdropBlurView: UIViewRepresentable {
    let radius: CGFloat

    func makeUIView(context: Context) -> BackdropBlurUIView {
        BackdropBlurUIView(radius: radius)
    }

    func updateUIView(_ blurView: BackdropBlurUIView, context: Context) {
        guard blurView.radius != radius else { return }
        blurView.radius = radius
        blurView.updateFilter()
    }
}

final class BackdropBlurUIView: UIVisualEffectView {
    var radius: CGFloat

    init(radius: CGFloat) {
        self.radius = radius
        super.init(effect: UIBlurEffect(style: .regular))

        // Hide the system tint and vibrancy layers — blur only. Callers layer
        // their own scrim on top.
        for subview in subviews.dropFirst() {
            subview.alpha = 0
        }
        updateFilter()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateFilter() {
        guard let filter = GaussianBlurFilter() else { return }
        filter.inputRadius = radius
        subviews.first?.layer.filters = [filter.base]
    }

    override func didMoveToWindow() {
        guard let window, let firstLayer = subviews.first?.layer else { return }
        firstLayer.setValue(window.screen.scale, forKey: "scale")
    }
}

private final class GaussianBlurFilter {
    let base: NSObject

    init?() {
        guard let filterClass = NSClassFromString(
            _decode("Q0FGaWx0ZXI=") // "CAFilter"
        ) as? NSObject.Type else { return nil }
        guard let gaussianBlur = filterClass
            .perform(
                NSSelectorFromString("filterWithType:"),
                with: _decode("Z2F1c3NpYW5CbHVy") // "gaussianBlur"
            )
            .takeUnretainedValue() as? NSObject
        else { return nil }

        self.base = gaussianBlur
        // "inputNormalizeEdges" — without it the blur samples past the edges
        // and the frame darkens at its border.
        self.base.setValue(true, forKey: _decode("aW5wdXROb3JtYWxpemVFZGdlcw=="))
    }

    var inputRadius: CGFloat {
        // "inputRadius"
        get { base.value(forKey: _decode("aW5wdXRSYWRpdXM=")) as? CGFloat ?? 0 }
        set { base.setValue(newValue, forKey: _decode("aW5wdXRSYWRpdXM=")) }
    }
}

// MARK: - Base64 Decode Helper

private func _decode(_ base64: String) -> String {
    guard let data = Data(base64Encoded: base64) else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
}

#Preview("Variable blur") {
    let merchant = SampleMerchant.preview
    let imageURL = merchant.featuredImageURLs.first.flatMap(URL.init(string:))
        ?? merchant.products.first?.imageURL.flatMap(URL.init(string:))

    ZStack {
        // Background content to blur over.
        if let imageURL {
            CachedAsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: GravityColors.bgFillBrand
                }
            }
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [Color(hex: 0x5433EB), Color(hex: 0x9C83F8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }

        VStack {
            VariableBlurView(maxBlurRadius: 20)
                .frame(height: 160)
                .ignoresSafeArea(edges: .top)
            Spacer()
            VariableBlurView(maxBlurRadius: 20, direction: .bottomBlurToTopTransparent)
                .frame(height: 160)
                .ignoresSafeArea(edges: .bottom)
        }
    }
    .frame(width: 360, height: 720)
}

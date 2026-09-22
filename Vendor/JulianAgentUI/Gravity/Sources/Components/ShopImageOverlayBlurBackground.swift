import SwiftUI
import UIKit

public struct ShopImageOverlayBlurBackground: View {
    private let tint: Color
    private let style: UIBlurEffect.Style

    public init(
        tint: Color = ShopColor.bgOverlayFixedDark20,
        style: UIBlurEffect.Style = .systemUltraThinMaterialLight
    ) {
        self.tint = tint
        self.style = style
    }

    public var body: some View {
        ZStack {
            ShopImageOverlayBlurView(style: style)
            tint
        }
        .allowsHitTesting(false)
    }
}

struct ShopImageOverlayBlurView: UIViewRepresentable {
    private let style: UIBlurEffect.Style

    init(style: UIBlurEffect.Style) {
        self.style = style
    }

    static func makeNonInteractiveUIView(style: UIBlurEffect.Style) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        view.isUserInteractionEnabled = false
        return view
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        Self.makeNonInteractiveUIView(style: style)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
        uiView.isUserInteractionEnabled = false
    }
}

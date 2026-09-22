import Gravity
import Nuke
import SwiftUI

struct ShopAskStartersView: View {
    let starters: [ShopAskStarter]
    let onSelect: (ShopAskStarter) -> Void

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: GravitySpacing.space8) {
                ShopAskStarterStack(starters: starters, onSelect: onSelect)
            }
        } else {
            ShopAskStarterStack(starters: starters, onSelect: onSelect)
        }
    }
}

private struct ShopAskStarterStack: View {
    let starters: [ShopAskStarter]
    let onSelect: (ShopAskStarter) -> Void
    @Environment(\.displayScale) private var displayScale
    @State private var preparedInput: ShopAskStarterPreparationInput?
    @State private var imageColors: [String: ShopImageSaturatedColor.Sample] = [:]

    var body: some View {
        let input = ShopAskStarterPreparationInput(starters: starters, displayScale: displayScale)
        ShopConversationStarterStack(items: starters, isReady: preparedInput == input) { starter in
            ShopAskStarterButton(starter: starter, imageColor: imageColors[starter.id]) { onSelect(starter) }
        }
        .task(id: input) {
            // Prepare the whole batch before releasing the existing bottom-first stagger.
            let colors = await ShopAskStarterAssetPreparation.prepare(input: input)
            guard !Task.isCancelled else { return }
            imageColors = colors
            preparedInput = input
        }
    }
}

struct ShopAskStarterPreparationInput: Equatable {
    let starters: [ShopAskStarter]
    let displayScale: CGFloat
}

enum ShopAskStarterAssetPreparation {
    static func prepare(
        input: ShopAskStarterPreparationInput,
        load: @escaping @Sendable (ImageRequest) async -> ShopImageSaturatedColor.Sample? = ShopAskStarterAssetPreparation.loadImage
    ) async -> [String: ShopImageSaturatedColor.Sample] {
        await withTaskGroup(of: (String, ShopImageSaturatedColor.Sample?).self) { group in
            for starter in input.starters {
                for image in starter.images.prefix(3) {
                    guard let prepared = ShopRemoteImageRequestBuilder.prepare(
                        sourceURL: image.url,
                        requestSize: CGSize(width: GravitySpacing.space32, height: GravitySpacing.space32),
                        displayScale: input.displayScale,
                        contentMode: .aspectFill
                    ) else { continue }
                    let id = starter.id
                    group.addTask { (id, await load(prepared.request)) }
                }
            }
            var colors: [String: ShopImageSaturatedColor.Sample] = [:]
            for await (id, sample) in group {
                if let sample, sample.saturation > (colors[id]?.saturation ?? -1) {
                    colors[id] = sample
                }
            }
            return colors
        }
    }

    static func loadImage(_ request: ImageRequest) async -> ShopImageSaturatedColor.Sample? {
        // Use the exact displayed request so the fanned stack mounts from decoded memory cache.
        // Missing/failed images settle with the existing placeholder and key-color fallback.
        guard let image = try? await ImagePipeline.shared.image(for: request),
              !Task.isCancelled, let cgImage = image.cgImage else { return nil }
        return ShopImageSaturatedColor.sample(image: cgImage)
    }
}

private struct ShopAskStarterButton: View {
    private enum ColorMetrics {
        /// A shared dark lightness keeps every sampled hue readable on its own
        /// subtle tint, while a chroma floor prevents muddy gray-browns.
        static let textLightness = 0.42
        static let minimumChroma = 0.18
        static let chromaScale = 2.25
        static let tintOpacity = 0.20
    }

    let starter: ShopAskStarter
    let imageColor: ShopImageSaturatedColor.Sample?
    let onSelect: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var textColor: Color? {
        let color = imageColor?.oklch ?? ShopOKLCHColor(hex: starter.keyColorHex)
        return color?
            .normalized(
                lightness: ColorMetrics.textLightness,
                minimumChroma: ColorMetrics.minimumChroma,
                chromaScale: ColorMetrics.chromaScale
            )
            .color
    }

    var body: some View {
        let textColor = textColor
        Button(action: onSelect) {
            HStack(spacing: GravitySpacing.space6) {
                if starter.images.isEmpty {
                    ShopIcon(.shopChatFilled, size: .small, color: GravityColor.textBrand)
                        .opacity(0.35)
                } else {
                    ShopRemoteImageFannedStack(images: starter.images, size: .xSmall,
                        placeholderIcon: starter.contextItems.first?.type == .order ? .order : .shopChat,
                        cornerRadius: GravityRadius.radius8, reservesFanOverflow: true)
                        // Reserve the same slot for one, two, or three thumbnails.
                        .frame(width: GravitySpacing.space48)
                        .accessibilityHidden(true)
                }
                ShopText(starter.title, style: .buttonLarge, color: textColor ?? GravityColor.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, starter.images.isEmpty ? GravitySpacing.space10 : GravitySpacing.space8)
            .padding(.trailing, GravitySpacing.space20)
            .padding(.vertical, GravitySpacing.space8)
            .frame(minHeight: ShopAgentUIKitComposerMetrics.barHeight)
            .modifier(ShopConversationStarterGlass(tint: textColor?.opacity(ColorMetrics.tintOpacity)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ask-starter-\(starter.id)")
    }
}

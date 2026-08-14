import SwiftUI

/// Editorial collage used for cross-category worlds and product spotlights.
struct StoryWorldLayout: View {
    let items: [ResolvedStoryProduct]
    var isActive = true

    var body: some View {
        ZStack {
            if items.indices.contains(0) {
                floatingProduct(items[0], index: 0, width: 190, height: 230, rotation: -5)
                    .offset(x: -62, y: 8)
            }
            if items.indices.contains(1) {
                floatingProduct(items[1], index: 1, width: 155, height: 180, rotation: 5)
                    .offset(x: 80, y: -55)
            }
            if items.indices.contains(2) {
                floatingProduct(items[2], index: 2, width: 135, height: 145, rotation: 3)
                    .offset(x: 88, y: 105)
            }
            if items.indices.contains(3) {
                floatingProduct(items[3], index: 3, width: 110, height: 120, rotation: -7)
                    .offset(x: -92, y: 150)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }

    private func floatingProduct(
        _ item: ResolvedStoryProduct,
        index: Int,
        width: CGFloat,
        height: CGFloat,
        rotation: Double
    ) -> some View {
        StoryProductImage(item: item)
            .frame(width: width, height: height)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .rotationEffect(.degrees(rotation))
            .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
            .storyProductPresentation(isPresented: isActive, index: index)
    }
}

/// A quiet visual shortlist; detailed comparison belongs in the next layer.
struct StoryShortlistLayout: View {
    let items: [ResolvedStoryProduct]
    var isActive = true

    private let tileSize: CGFloat = 112
    private let spacing = GravitySpacing.space8
    private var columns: [GridItem] {
        [
            GridItem(.fixed(tileSize), spacing: spacing),
            GridItem(.fixed(tileSize)),
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(items.prefix(4).enumerated()), id: \.element.id) { index, item in
                StoryProductImage(item: item)
                    .frame(width: tileSize, height: tileSize)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    .storyProductPresentation(isPresented: isActive, index: index)
            }
        }
        .frame(width: tileSize * 2 + spacing)
        .frame(maxWidth: .infinity)
    }
}

/// A constrained hero-plus-supporting-items composition for routines and rooms.
struct StorySetupLayout: View {
    let items: [ResolvedStoryProduct]
    var isActive = true

    var body: some View {
        GeometryReader { geometry in
            let spacing = GravitySpacing.space8
            let smallWidth = (geometry.size.width - spacing * 2) / 3

            VStack(spacing: spacing) {
                if let first = items.first {
                    StoryProductImage(item: first)
                        .frame(width: geometry.size.width, height: 190)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                        .storyProductPresentation(isPresented: isActive, index: 0)
                }

                HStack(spacing: spacing) {
                    ForEach(Array(items.dropFirst().prefix(3).enumerated()), id: \.element.id) { index, item in
                        StoryProductImage(item: item)
                            .frame(width: smallWidth, height: 108)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                            .storyProductPresentation(isPresented: isActive, index: index + 1)
                    }
                }
            }
            .frame(width: geometry.size.width, alignment: .leading)
        }
        .frame(height: 306)
    }
}

private struct StoryProductImage: View {
    let item: ResolvedStoryProduct

    var body: some View {
        ProductImageView(product: item.product, merchant: item.merchant)
            .scaleEffect(1.16)
    }
}

private struct StoryProductPresentationModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isPresented: Bool
    let index: Int

    private var presentationAnimation: Animation {
        if reduceMotion {
            return .easeOut(duration: 0.16)
        }
        if isPresented {
            return .spring(response: 0.32, dampingFraction: 0.9)
                .delay(Double(index) * 0.045)
        }
        return .easeOut(duration: 0.14)
    }

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .blur(radius: isPresented || reduceMotion ? 0 : 4)
            .offset(y: isPresented || reduceMotion ? 0 : 12)
            .scaleEffect(isPresented || reduceMotion ? 1 : 0.96)
            .animation(presentationAnimation, value: isPresented)
    }
}

private extension View {
    func storyProductPresentation(isPresented: Bool, index: Int) -> some View {
        modifier(StoryProductPresentationModifier(isPresented: isPresented, index: index))
    }
}

#Preview("World layout") {
    StoryWorldLayout(items: FeedStory.preview.resolvedProducts(from: SampleMerchant.previews))
        .padding()
        .background(Color(hex: FeedStory.preview.accentHex))
}

#Preview("Shortlist layout") {
    let story = FeedStory.previews.first(where: { $0.format == .shortlist }) ?? FeedStory.preview
    StoryShortlistLayout(items: story.resolvedProducts(from: SampleMerchant.previews))
        .padding()
        .background(Color(hex: story.accentHex))
}

#Preview("Setup layout") {
    let story = FeedStory.previews.first(where: { $0.format == .setup }) ?? FeedStory.preview
    StorySetupLayout(items: story.resolvedProducts(from: SampleMerchant.previews))
        .padding()
        .background(Color(hex: story.accentHex))
}

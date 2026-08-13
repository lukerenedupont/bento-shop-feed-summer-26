import SwiftUI

/// A nested flick-and-stick feed that deepens one home story. It deliberately
/// reuses the same card grammar so entering and leaving a story feels obvious.
struct StoryDetailPage: View {
    let storyID: String
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator

    private struct FocusedEntry: Identifiable {
        let story: FeedStory
        let primary: ResolvedStoryProduct
        var id: String { story.id }
    }

    private var merchants: [SampleMerchant] { SampleMerchant.all }
    private var parentStory: FeedStory? {
        PersonalizedFeedStories.all.first { $0.id == storyID }
    }
    private var parentItems: [ResolvedStoryProduct] {
        parentStory?.resolvedProducts(from: merchants) ?? []
    }

    /// Each product becomes a deeper content card, with the remaining products
    /// retained as visual context rather than turning the destination into a grid.
    private var focusedEntries: [FocusedEntry] {
        guard let parentStory else { return [] }
        return parentItems.indices.map { index in
            let ordered = Array(parentItems[index...]) + Array(parentItems[..<index])
            let focusedStory = FeedStory(
                id: "\(parentStory.id)-\(parentItems[index].id)",
                eyebrow: parentItems[index].merchant.name,
                title: parentItems[index].product.title,
                subtitle: "",
                format: .world,
                topicKeys: parentStory.topicKeys,
                accentHex: parentStory.accentHex,
                coverImageName: nil,
                destinationLabel: "View product",
                products: ordered.map {
                    .init(merchantID: $0.merchant.id, productID: $0.product.id)
                }
            )
            return FocusedEntry(story: focusedStory, primary: parentItems[index])
        }
    }

    var body: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 32, 377)
            let cardHeight = cardWidth * 1.71

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: GravitySpacing.space16) {
                    ForEach(focusedEntries) { entry in
                        StoryFeedCard(
                            story: entry.story,
                            merchants: merchants,
                            width: cardWidth,
                            height: cardHeight,
                            onTap: {
                                coordinator.pushRoute(.product(
                                    merchantId: entry.primary.merchant.id,
                                    productId: entry.primary.product.id
                                ))
                            }
                        )
                        .matchedTransitionSource(id: entry.primary.product.id, in: namespace)
                        .id(entry.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, max((geo.size.height - cardHeight) / 2 - 8, 8))
                .padding(.bottom, max((geo.size.height - cardHeight) / 2, 8))
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offset in
                coordinator.updateScrollOffset(offset)
            }
        }
        .background(GravityColors.bg.ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            HStack {
                Text(parentStory?.title ?? "Focused feed")
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(GravityColors.text)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.vertical, GravitySpacing.space8)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        StoryDetailPage(storyID: FeedStory.preview.id, namespace: ns)
    }
    .environment(NavigationCoordinator())
}

import SwiftUI

/// PROTOTYPE review harness. Launch with `-nextGenerationGallery` and use the
/// arrows to inspect every generated card without traversing the feed.
struct NextGenerationFeedGallery: View {
    @State private var selectedIndex: Int

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let requestedIndex: Int = if let flag = arguments.firstIndex(of: "-nextGenerationGallery"),
                                     arguments.indices.contains(flag + 1) {
            Int(arguments[flag + 1]) ?? 0
        } else {
            0
        }
        _selectedIndex = State(initialValue: min(max(requestedIndex, 0), NextGenerationCardLayout.allCases.count - 1))
    }

    private var merchants: [SampleMerchant] { SampleMerchant.all }

    private var cards: [NextGenerationFeedCardSpec] {
        NextGenerationFeedCardCatalog.cards(
            topic: BuyerFeedTopic(
                id: "for-you",
                label: "For you",
                storyIDs: [],
                evidence: .observed
            ),
            sourceStories: [],
            merchants: merchants
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let card = cards[selectedIndex]
            // RootView's debug overlay can inherit an unconstrained proposal
            // while the underlying navigation stack is transitioning. Clamp
            // the review canvas to the current phone-class viewport.
            let cardWidth = min(proxy.size.width, 430)
            let cardHeight = min(proxy.size.height, 932)
            ZStack(alignment: .bottom) {
                Color.black.ignoresSafeArea()
                NextGenerationFeedCardView(
                    spec: card,
                    merchants: merchants,
                    width: cardWidth,
                    height: cardHeight,
                    foregroundTopPadding: max(proxy.safeAreaInsets.top, 62) + GravitySpacing.space20,
                    isActive: true
                )
                reviewControls(card: card)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, GravitySpacing.space16))
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, cards[selectedIndex].prefersDarkNavigationText ? .light : .dark)
    }

    private func reviewControls(card: NextGenerationFeedCardSpec) -> some View {
        HStack(spacing: GravitySpacing.space16) {
            Button { move(-1) } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            VStack(spacing: 1) {
                Text("\(selectedIndex + 1) of \(cards.count)")
                    .font(GravityFont.medium.fixedFont(size: 11))
                    .foregroundStyle(.secondary)
                Text(card.layout.rawValue)
                    .font(GravityFont.semiBold.fixedFont(size: 14))
            }
            .frame(minWidth: 150)
            Button { move(1) } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.black)
        .padding(.horizontal, GravitySpacing.space12)
        .padding(.vertical, GravitySpacing.space6)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 18, y: 5)
    }

    private func move(_ direction: Int) {
        HapticFeedback.selection.fire()
        withAnimation(SpringPreset.responsive) {
            selectedIndex = (selectedIndex + direction + cards.count) % cards.count
        }
    }
}

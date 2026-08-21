import SwiftUI

/// Shared top-level buyer navigation used by every personalized feed.
///
/// This component owns only header presentation and horizontal rail behavior.
/// `HomePage` remains responsible for feed selection and navigation state.
struct BuyerFeedNavigationBar: View {
    let profile: BuyerPreviewProfile
    let topics: [BuyerFeedTopic]
    let selectedTopicID: String
    let feedExpansionProgress: CGFloat
    var usesInverseStyle = false
    var usesFeedBackdropStyle = false
    var usesHolidayPillStyle = false
    let selectionNamespace: Namespace.ID
    var onSelectTopic: (BuyerFeedTopic) -> Void
    var onSelectBuyer: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            topicRail
            avatarButton
                .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, GravitySpacing.space16)
        .padding(.vertical, GravitySpacing.space4)
    }

    private var avatarButton: some View {
        return Button {
            HapticFeedback.light.fire()
            onSelectBuyer()
        } label: {
            BuyerPreviewAvatar(
                profile: profile,
                size: FeedNavigationStyle.avatarSize
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Switch preview buyer")
    }

    private var topicRail: some View {
        ScrollViewReader { proxy in
            let leadingInset = FeedNavigationStyle.avatarSize + GravitySpacing.space8
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(topics) { topic in
                        topicButton(topic)
                            .id(topic.id)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .scrollTargetLayout()
            }
            .contentMargins(.leading, leadingInset, for: .scrollContent)
            .contentMargins(.trailing, GravitySpacing.space16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
            .mask {
                HStack(spacing: 0) {
                    // Let labels travel beneath the avatar, then remove them
                    // before they can emerge from its opposite edge. The
                    // vertical expansion preserves the selected-pill shadow.
                    Color.clear
                        .frame(width: FeedNavigationStyle.avatarSize / 2)
                    Color.black
                }
                .padding(.vertical, -GravitySpacing.space16)
            }
            .onChange(of: selectedTopicID) { _, _ in
                guard let selectedIndex = topics.firstIndex(where: { $0.id == selectedTopicID }),
                      selectedIndex > 2 else { return }
                withAnimation(.easeOut(duration: 0.20)) {
                    proxy.scrollTo(selectedTopicID, anchor: .center)
                }
            }
            .onChange(of: profile.id) { _, _ in
                proxy.scrollTo(selectedTopicID, anchor: .leading)
            }
        }
        .frame(height: FeedNavigationStyle.controlSize)
    }

    private func topicButton(_ topic: BuyerFeedTopic) -> some View {
        let isIlluminatedHolidaySelection = usesHolidayPillStyle
            && topic.id == selectedTopicID
            && ["for-you", "holiday-sale", "gift-guides"].contains(topic.id)

        return Button {
            onSelectTopic(topic)
        } label: {
            Text(topic.label)
                .font(FeedNavigationStyle.labelFont)
                .foregroundStyle(
                    labelColor(for: topic)
                )
                .shadow(
                    color: topic.id == selectedTopicID
                        ? .clear
                        : .black.opacity(0.28 * feedExpansionProgress),
                    radius: 7,
                    y: 2
                )
                .padding(
                    .horizontal,
                    topic.id == "gift-guides"
                        ? FeedNavigationStyle.pillHorizontalPadding + 4
                        : FeedNavigationStyle.pillHorizontalPadding
                )
                .frame(height: FeedNavigationStyle.controlSize)
                .contentShape(Capsule())
                .background {
                    if topic.id == selectedTopicID {
                        SelectedTopicPill(
                            showsHolidayLights: isIlluminatedHolidaySelection
                        )
                        .matchedGeometryEffect(
                            id: "selected-topic",
                            in: selectionNamespace
                        )
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(topic.id == selectedTopicID ? .isSelected : [])
    }

    private func labelColor(for topic: BuyerFeedTopic) -> Color {
        if topic.id == selectedTopicID {
            return GravityColors.textFixedDark
        }
        if usesInverseStyle {
            return .white.opacity(0.75)
        }
        if usesFeedBackdropStyle {
            return .white.opacity(0.82)
        }
        return GravityColors.textTertiary
    }

}

/// One stable matched-geometry surface moves between tabs. Seasonal lights
/// overflow that surface visually but never participate in its layout, which
/// keeps the focus pill aligned throughout the transition.
private struct SelectedTopicPill: View {
    let showsHolidayLights: Bool

    var body: some View {
        Capsule()
            .fill(FeedNavigationStyle.selectedFill)
            .overlay {
                Capsule()
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.selectedTopic)
            .overlay {
                if showsHolidayLights {
                    HolidayPillLights()
                }
            }
    }
}

private struct HolidayPillLights: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 0.34, paused: reduceMotion)) { context in
                let phase = reduceMotion
                    ? 1.0
                    : (sin(context.date.timeIntervalSinceReferenceDate * 4.2) + 1) / 2

                Image("holiday-gift-guides-nav-lights")
                    .resizable()
                    .frame(width: proxy.size.width + 10, height: 60)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .opacity(0.92 + (phase * 0.08))
                    .brightness(phase * 0.025)
                    .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }
}

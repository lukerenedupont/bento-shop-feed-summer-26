import SwiftUI

/// Shared top-level buyer navigation used by every personalized feed.
///
/// This component owns only header presentation and horizontal rail behavior.
/// `HomePage` remains responsible for feed selection and navigation state.
struct BuyerFeedNavigationBar: View {
    let profile: BuyerPreviewProfile
    let topics: [BuyerFeedTopic]
    let selectedTopicID: String
    @Bindable var chromeTransitionState: FeedChromeTransitionState
    var usesInverseStyle = false
    var usesFeedBackdropStyle = false
    var usesHolidayPillStyle = false
    let selectionNamespace: Namespace.ID
    var onSelectTopic: (BuyerFeedTopic) -> Void
    var onSelectBuyer: () -> Void
    var onAddFeed: () -> Void = {}
    var onManageFeeds: () -> Void = {}

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
            .overlay {
                Circle()
                    .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Switch preview buyer")
    }

    private var topicRail: some View {
        ScrollViewReader { proxy in
            let leadingInset = FeedNavigationStyle.avatarSize + GravitySpacing.space6
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(topics) { topic in
                        topicButton(topic)
                            .id(topic.id)
                    }
                    addFeedButton
                        .id("add-feed")
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
        let isSelected = topic.id == selectedTopicID
        let isIlluminatedHolidaySelection = usesHolidayPillStyle
            && isSelected
            && ["for-you", "holiday-sale", "gift-guides"].contains(topic.id)

        return transitioningLabel(for: topic)
            .shadow(
                color: isSelected
                    ? .clear
                    : .black.opacity(0.28 * chromeTransitionState.progress),
                radius: 7,
                y: 2
            )
            .padding(
                .horizontal,
                isSelected
                    ? FeedNavigationStyle.selectedPillHorizontalPadding
                    : FeedNavigationStyle.pillHorizontalPadding
            )
            .frame(height: FeedNavigationStyle.controlSize)
            .contentShape(Capsule())
            .background {
                if isSelected {
                    SelectedTopicPill(
                        showsHolidayLights: isIlluminatedHolidaySelection
                    )
                    .matchedGeometryEffect(
                        id: "selected-topic",
                        in: selectionNamespace
                    )
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.45, maximumDistance: 20)
                    .exclusively(before: TapGesture())
                    .onEnded { result in
                        switch result {
                        case .first:
                            HapticFeedback.medium.fire()
                            onManageFeeds()
                        case .second:
                            onSelectTopic(topic)
                        }
                    }
            )
            .accessibilityLabel(topic.label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction {
                onSelectTopic(topic)
            }
            .accessibilityAction(named: "Manage feeds") {
                HapticFeedback.medium.fire()
                onManageFeeds()
            }
    }

    private var addFeedButton: some View {
        Button {
            HapticFeedback.light.fire()
            onAddFeed()
        } label: {
            Image("icon-plus-sign-small", bundle: .main)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: GravitySpacing.space16, height: GravitySpacing.space16)
                .foregroundStyle(GravityColors.textFixedDark)
                .frame(
                    width: FeedNavigationStyle.controlSize,
                    height: FeedNavigationStyle.controlSize
                )
                .background {
                    SelectedTopicPill(showsHolidayLights: false)
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Add feed")
    }

    @ViewBuilder
    private func transitioningLabel(for topic: BuyerFeedTopic) -> some View {
        let label = Text(topic.label)
            .gravityTextStyle(GravityTypography.buttonLarge)
            .lineLimit(1)

        if topic.id == selectedTopicID {
            label.foregroundStyle(GravityColors.textFixedDark)
        } else if usesInverseStyle {
            label.foregroundStyle(.white.opacity(0.75))
        } else if !usesFeedBackdropStyle {
            // Following, Deals, and the resting utility surface are authored
            // on white. Ignore stale feed-card transition progress when those
            // destinations replace the dark media backdrop.
            label.foregroundStyle(GravityColors.textSecondary)
        } else {
            let progress = chromeTransitionState.progress
            ZStack {
                label
                    .foregroundStyle(GravityColors.textSecondary)
                    .opacity(1 - progress)
                label
                    .foregroundStyle(.white.opacity(0.82))
                    .opacity(progress)
            }
        }
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
            .glassEffect(.regular, in: .capsule)
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

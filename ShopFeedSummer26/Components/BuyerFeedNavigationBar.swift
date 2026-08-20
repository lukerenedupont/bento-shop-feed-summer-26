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
    let selectionNamespace: Namespace.ID
    @Binding var railOffset: CGFloat
    @Binding var railContentWidth: CGFloat
    var onSelectTopic: (BuyerFeedTopic) -> Void
    var onSelectBuyer: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

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
        Button {
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
        GeometryReader { geometry in
            let leadingInset = FeedNavigationStyle.avatarSize + GravitySpacing.space8
            let effectiveOffset = clampedOffset(
                railOffset + dragOffset,
                viewportWidth: geometry.size.width,
                leadingInset: leadingInset
            )

            ZStack(alignment: .leading) {
                Color.clear

                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(topics) { topic in
                        topicButton(topic)
                            .id(topic.id)
                    }

                    Color.clear
                        .frame(width: GravitySpacing.space16, height: 1)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: leadingInset + effectiveOffset)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { _, width in
                    railContentWidth = width
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let proposed = railOffset + value.predictedEndTranslation.width
                        withAnimation(.easeOut(duration: 0.18)) {
                            railOffset = clampedOffset(
                                proposed,
                                viewportWidth: geometry.size.width,
                                leadingInset: leadingInset
                            )
                        }
                    }
            )
        }
        .frame(height: FeedNavigationStyle.controlSize)
    }

    private func topicButton(_ topic: BuyerFeedTopic) -> some View {
        Button {
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
                        : .black.opacity(0.18 * feedExpansionProgress),
                    radius: 4,
                    y: 1
                )
                .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
                .frame(height: FeedNavigationStyle.controlSize)
                .contentShape(Capsule())
                .background {
                    if topic.id == selectedTopicID {
                        Capsule()
                            .fill(
                                usesInverseStyle
                                    ? Color.white.opacity(0.20)
                                    : Color.white
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        usesInverseStyle
                                            ? Color.white.opacity(0.18)
                                            : Color.black.opacity(0.06),
                                        lineWidth: 0.5
                                    )
                            }
                            .gravityShadow(GravityShadows.selectedTopic)
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
        if usesInverseStyle {
            return topic.id == selectedTopicID
                ? .white
                : .white.opacity(0.75)
        }
        if usesFeedBackdropStyle {
            // The selected chip remains the established white surface with
            // dark type; only the uncontained rail labels invert over media.
            return topic.id == selectedTopicID
                ? GravityColors.textFixedDark
                : .white.opacity(0.82)
        }
        return topic.id == selectedTopicID
            ? GravityColors.textFixedDark
            : GravityColors.textTertiary
    }

    private func clampedOffset(
        _ proposed: CGFloat,
        viewportWidth: CGFloat,
        leadingInset: CGFloat
    ) -> CGFloat {
        let minimum = min(0, viewportWidth - leadingInset - railContentWidth)
        return min(0, max(minimum, proposed))
    }
}

import SwiftUI

/// A pushed destination that renders a single story with the same landing
/// grammar as a topic feed — cover/accent header, merchants, and masonry —
/// so drilling into a subcategory feels identical to opening its topic.
struct StoryTopicPage: View {
    let storyID: String
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var previousNavBarTint: Color?

    private var isLegacyStory: Bool {
        PersonalizedFeedCatalog.current.stories.contains { $0.id == storyID } == false
    }
    private var merchants: [SampleMerchant] {
        isLegacyStory ? LegacyFeedArchive.merchants : SampleMerchant.all
    }
    private var story: FeedStory? {
        PersonalizedFeedStories.all.first { $0.id == storyID }
            ?? PersonalizedFeedCatalog.bundled.stories.first { $0.id == storyID }
    }

    /// The parent topic whose feed contains this story — its cover and
    /// sampled accent carry through so drill-ins stay in the same world.
    private var parentTopic: FeedTopic? {
        PersonalizedFeedCatalog.current.topics.first {
            $0.id != "for-you" && ($0.storyIDs?.contains(storyID) ?? false)
        }
        ?? PersonalizedFeedCatalog.bundled.topics.first {
            ($0.storyIDs?.contains(storyID) ?? false)
                || ($0.subtopics?.contains { $0.storyID == storyID } ?? false)
        }
    }

    private var parentStories: [FeedStory] {
        guard let parentTopic else { return [] }
        let catalog = isLegacyStory ? PersonalizedFeedCatalog.bundled : PersonalizedFeedCatalog.current
        let byID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
        return (parentTopic.storyIDs ?? []).compactMap { byID[$0] }
    }

    private var siblingSubtopics: [FeedTopic.Subtopic] {
        if let curated = parentTopic?.subtopics, !curated.isEmpty { return curated }
        return parentStories.map {
            .init(label: $0.title.split(separator: " ").prefix(3).joined(separator: " "), storyID: $0.id)
        }
    }

    private var parentLeadStory: FeedStory? {
        guard let leadID = parentTopic?.storyIDs?.first else { return nil }
        return PersonalizedFeedStories.all.first { $0.id == leadID }
            ?? PersonalizedFeedCatalog.bundled.stories.first { $0.id == leadID }
    }

    var body: some View {
        if let story {
            TopicLandingView(
                topic: FeedTopic(
                    id: story.id,
                    label: story.title,
                    storyTopicKey: nil,
                    storyIDs: [story.id],
                    subtopics: nil,
                    relatedMerchantIDs: nil,
                    merchandisingBlocks: nil
                ),
                stories: [story],
                merchants: merchants,
                headerCoverImageName: parentLeadStory?.coverImageName,
                surfaceAccentHex: parentLeadStory?.accentHex ?? story.accentHex,
                // Chapters, not covers: shorter header with the parent
                // world's name as an eyebrow so drill-ins stay oriented.
                headerEyebrow: parentTopic?.label,
                compactHeader: true
            )
            .environment(\.colorScheme, .dark)
            .toolbar(.hidden, for: .navigationBar)
            .navigationTransition(
                .zoom(sourceID: "subtopic-\(storyID)", in: namespace)
            )
            .safeAreaBar(edge: .top) {
                drillInNavigation
                .padding(.vertical, GravitySpacing.space4)
            }
            .onAppear {
                previousNavBarTint = coordinator.navBarBlurTint
                withAnimation(.easeOut(duration: 0.22)) {
                    // Same immersive treatment as TopicPage: top chip only.
                    coordinator.showNavBar = false
                    coordinator.navBarBlurTint = Color(hex: parentLeadStory?.accentHex ?? story.accentHex)
                }
            }
            .onDisappear {
                // Fallback for swipe-back pops; idempotent after the chip.
                withAnimation(.easeOut(duration: 0.15)) {
                    coordinator.showNavBar = true
                    if let previousNavBarTint {
                        coordinator.navBarBlurTint = previousNavBarTint
                    }
                }
            }
        }
    }

    private var drillInNavigation: some View {
        ZStack(alignment: .leading) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FeedNavigationStyle.itemSpacing) {
                        ForEach(siblingSubtopics, id: \.storyID) { subtopic in
                            Button {
                                guard subtopic.storyID != storyID else { return }
                                HapticFeedback.light.fire()
                                coordinator.replaceCurrentRoute(.story(storyId: subtopic.storyID))
                            } label: {
                                Text(subtopic.label)
                                    .font(FeedNavigationStyle.labelFont)
                                    .foregroundStyle(subtopic.storyID == storyID ? .black : .white)
                                    .lineLimit(1)
                                    .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
                                    .frame(height: FeedNavigationStyle.controlSize)
                                    .background {
                                        if subtopic.storyID == storyID {
                                            Capsule()
                                                .fill(FeedNavigationStyle.selectedFill)
                                                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(
                                id: "subtopic-\(subtopic.storyID)",
                                in: namespace
                            )
                            .id(subtopic.storyID)
                        }
                    }
                }
                .contentMargins(.leading, FeedNavigationStyle.railLeadingInset, for: .scrollContent)
                .contentMargins(.trailing, FeedNavigationStyle.railTrailingInset, for: .scrollContent)
                .onAppear {
                    proxy.scrollTo(storyID, anchor: .center)
                }
            }

            Button {
                HapticFeedback.light.fire()
                coordinator.popCurrentPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(FeedNavigationStyle.iconFont)
                    .foregroundStyle(.black)
                    .frame(width: FeedNavigationStyle.controlSize, height: FeedNavigationStyle.controlSize)
                    .background(FeedNavigationStyle.selectedFill, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.leading, GravitySpacing.space16)
            .accessibilityLabel("Back")
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, minHeight: FeedNavigationStyle.controlSize, alignment: .leading)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        StoryTopicPage(storyID: FeedStory.preview.id, namespace: namespace)
    }
    .environment(NavigationCoordinator())
}

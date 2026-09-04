import SwiftUI

private struct CreatedFeed: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let sourceCategoryID: String
    let storyIDs: [String]

    var topic: BuyerFeedTopic {
        BuyerFeedTopic(
            id: id,
            label: name,
            sourceCategoryID: sourceCategoryID,
            storyIDs: storyIDs,
            evidence: .discovery
        )
    }
}

private struct BuyerFeedCustomization: Codable {
    var createdFeeds: [CreatedFeed] = []
    var orderedFeedIDs: [String] = []
    var hiddenAuthoredFeedIDs: Set<String> = []
}

/// Prototype persistence for shopper-authored feeds. State is intentionally
/// scoped by preview buyer so a feed created for one dossier never leaks into
/// another buyer's navigation.
@Observable
@MainActor
final class CustomFeedStore {
    static let shared = CustomFeedStore()

    private static let defaultsKey = "customFeedsByPreviewBuyer"
    private static let fixedFeedIDs: Set<String> = ["for-you", "following", "deals"]

    private var customizationByBuyerID: [String: BuyerFeedCustomization]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(
               [String: BuyerFeedCustomization].self,
               from: data
           ) {
            customizationByBuyerID = decoded
        } else {
            customizationByBuyerID = [:]
        }
    }

    func navigationTopics(
        for buyerID: String,
        authoredTopics: [BuyerFeedTopic]
    ) -> [BuyerFeedTopic] {
        guard let forYou = authoredTopics.first(where: { $0.id == "for-you" })
            ?? authoredTopics.first else {
            return []
        }
        return [forYou] + managedTopics(for: buyerID, authoredTopics: authoredTopics)
    }

    func managedTopics(
        for buyerID: String,
        authoredTopics: [BuyerFeedTopic]
    ) -> [BuyerFeedTopic] {
        let customization = customizationByBuyerID[buyerID] ?? BuyerFeedCustomization()
        let authored = authoredTopics.filter { !Self.fixedFeedIDs.contains($0.id) }
        let created = customization.createdFeeds.map(\.topic)
        let available = (authored + created).filter {
            !customization.hiddenAuthoredFeedIDs.contains($0.id)
        }
        let byID = Dictionary(uniqueKeysWithValues: available.map { ($0.id, $0) })
        let availableIDs = Set(byID.keys)
        let persistedOrder = customization.orderedFeedIDs.filter(availableIDs.contains)
        let newIDs = available.map(\.id).filter { !persistedOrder.contains($0) }
        return (persistedOrder + newIDs).compactMap { byID[$0] }
    }

    @discardableResult
    func createFeed(
        named rawName: String,
        for buyerID: String,
        using placeholderSource: BuyerFeedTopic
    ) -> BuyerFeedTopic? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        var customization = customizationByBuyerID[buyerID] ?? BuyerFeedCustomization()
        let feed = CreatedFeed(
            id: "created-feed-\(UUID().uuidString.lowercased())",
            name: name,
            sourceCategoryID: placeholderSource.sourceCategoryID,
            storyIDs: placeholderStoryIDs(
                from: placeholderSource.storyIDs,
                offset: customization.createdFeeds.count
            )
        )
        customization.createdFeeds.append(feed)
        customization.orderedFeedIDs.append(feed.id)
        customizationByBuyerID[buyerID] = customization
        persist()
        return feed.topic
    }

    func moveFeed(
        _ feedID: String,
        toIndex targetIndex: Int,
        for buyerID: String,
        authoredTopics: [BuyerFeedTopic]
    ) {
        var orderedIDs = managedTopics(
            for: buyerID,
            authoredTopics: authoredTopics
        ).map(\.id)
        guard let sourceIndex = orderedIDs.firstIndex(of: feedID),
              orderedIDs.indices.contains(targetIndex),
              sourceIndex != targetIndex else { return }

        orderedIDs.remove(at: sourceIndex)
        orderedIDs.insert(feedID, at: targetIndex)

        var customization = customizationByBuyerID[buyerID] ?? BuyerFeedCustomization()
        customization.orderedFeedIDs = orderedIDs
        customizationByBuyerID[buyerID] = customization
        persist()
    }

    func deleteFeed(
        _ feedID: String,
        for buyerID: String,
        authoredTopics: [BuyerFeedTopic]
    ) {
        guard !Self.fixedFeedIDs.contains(feedID) else { return }
        var customization = customizationByBuyerID[buyerID] ?? BuyerFeedCustomization()

        if customization.createdFeeds.contains(where: { $0.id == feedID }) {
            customization.createdFeeds.removeAll { $0.id == feedID }
        } else if authoredTopics.contains(where: { $0.id == feedID }) {
            customization.hiddenAuthoredFeedIDs.insert(feedID)
        }
        customization.orderedFeedIDs.removeAll { $0 == feedID }
        customizationByBuyerID[buyerID] = customization
        persist()
    }

    private func placeholderStoryIDs(from storyIDs: [String], offset: Int) -> [String] {
        guard !storyIDs.isEmpty else { return [] }
        let count = min(2, storyIDs.count)
        return (0..<count).map { index in
            storyIDs[(offset + index) % storyIDs.count]
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customizationByBuyerID) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}

struct CreateFeedSheet: View {
    let onCreate: (String) -> Void

    private static let commonEnglishGivenNames = "|aaron|abigail|adam|alex|alexander|alexis|alice|amanda|amber|amy|andrew|angela|anna|anthony|arthur|ashley|ava|ben|benjamin|bethany|brandon|brian|brittany|cameron|carl|caroline|carolyn|charles|charlotte|chloe|chris|christian|christopher|claire|daniel|david|deborah|diana|dominic|donna|dylan|edward|eleanor|elizabeth|ella|ellie|emily|emma|eric|ethan|evelyn|faith|george|grace|hannah|harry|hazel|heather|henry|holly|ian|isaac|isabella|jack|jacob|james|jane|jason|jennifer|jessica|joan|joe|john|jonathan|jordan|joseph|joshua|julia|julian|justin|karen|katherine|katie|kevin|kimberly|laura|lauren|leo|leon|liam|lily|linda|lisa|logan|lucas|lucy|luke|madeline|madison|margaret|maria|mark|mary|mason|matthew|megan|melissa|mia|michael|michelle|nancy|natalie|nicholas|nicole|noah|oliver|olivia|owen|pamela|patrick|paul|penelope|peter|rachel|rebecca|richard|robert|rose|ruby|ryan|samantha|samuel|sarah|scarlett|sean|sebastian|sophia|sophie|stephanie|stephen|susan|taylor|thomas|timothy|victoria|violet|william|willow|zachary|"

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFieldIsFocused: Bool
    @State private var name = ""
    @State private var removedLeonMatch = false

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var detectsLeon: Bool {
        trimmedName.range(of: "leon", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private var showsLeonPersona: Bool {
        detectsLeon && !removedLeonMatch
    }

    private var detectsEnglishPersonalName: Bool {
        trimmedName.lowercased().split(whereSeparator: { !$0.isLetter }).contains { token in
            Self.commonEnglishGivenNames.contains("|\(token)|")
        }
    }

    private var showsPersonaOptions: Bool {
        detectsLeon || detectsEnglishPersonalName
    }

    var body: some View {
        sheetSurface
            .padding(.horizontal, GravitySpacing.space8)
            .padding(.bottom, GravitySpacing.space8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background(Color.black.opacity(0.18).ignoresSafeArea())
            .presentationBackground(.clear)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    nameFieldIsFocused = true
                }
            }
    }

    private var sheetSurface: some View {
        VStack(spacing: 0) {
            VStack(spacing: GravitySpacing.space40) {
                header
                nameField
                if showsPersonaOptions {
                    personaOptions
                }
            }
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.top, GravitySpacing.space20)
            .padding(.bottom, showsPersonaOptions ? GravitySpacing.space44 : 64)

            Text("Shop will use this name to shape your feed. You can fine-tune it anytime.")
                .gravityTextStyle(GravityTypography.caption)
                .foregroundStyle(GravityColors.textTertiary)
                .multilineTextAlignment(.center)
                .frame(width: 295, height: 32, alignment: .top)
                .padding(.horizontal, GravitySpacing.space20)
                .padding(.bottom, GravitySpacing.space16)
        }
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: GravityRadius.r40, style: .continuous)
                .fill(GravityColors.bgFill)
        }
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r40, style: .continuous))
        .shadow(
            color: GravityColors.shadow200,
            radius: GravitySpacing.space24,
            y: GravitySpacing.space4
        )
        .onChange(of: name) { oldValue, newValue in
            if oldValue != newValue && !detectsLeon {
                removedLeonMatch = false
            }
        }
    }

    private var header: some View {
        HStack {
            sheetIconButton(
                icon: .leftChevron,
                foreground: GravityColors.text,
                background: GravityColors.bgFill,
                accessibilityLabel: "Close"
            ) {
                dismiss()
            }

            Spacer()

            sheetIconButton(
                icon: .checkmark,
                foreground: GravityColors.textFixedLight,
                background: GravityColors.bgFillBrand,
                accessibilityLabel: "Create feed"
            ) {
                guard !trimmedName.isEmpty else { return }
                HapticFeedback.medium.fire()
                onCreate(trimmedName)
            }
            .disabled(trimmedName.isEmpty)
        }
    }

    private var nameField: some View {
        TextField("Photography", text: $name)
            .font(GravityFont.bold.fixedFont(size: 36))
            .tracking(GravityLetterSpacing.slammed)
            .foregroundStyle(GravityColors.text)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($nameFieldIsFocused)
            .frame(height: 42)
            .accessibilityLabel("Feed name")
            .onSubmit {
                guard !trimmedName.isEmpty else { return }
                onCreate(trimmedName)
            }
    }

    private var personaOptions: some View {
        HStack(spacing: GravitySpacing.space6) {
            if showsLeonPersona {
                leonPersonaChip
                    .transition(.scale.combined(with: .opacity))
            }
            createPersonaChip
        }
        .frame(height: GravitySpacing.space40)
        .animation(.easeOut(duration: 0.16), value: showsLeonPersona)
    }

    private var leonPersonaChip: some View {
        HStack(spacing: GravitySpacing.space8) {
            Image("leon-persona", bundle: .main)
                .resizable()
                .scaledToFill()
                .frame(width: GravitySpacing.space32, height: GravitySpacing.space32)
                .clipShape(Circle())
                .overlay {
                    Circle().strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
                }
            Text("Leon")
                .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(GravityColors.text)
        }
        .padding(.leading, GravitySpacing.space4)
        .padding(.trailing, GravitySpacing.space16)
        .frame(height: GravitySpacing.space40)
        .background(GravityColors.bgFill, in: Capsule())
        .overlay { Capsule().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5) }
        .shadow(color: GravityColors.shadow100, radius: GravitySpacing.space8, y: GravitySpacing.space2)
        .overlay(alignment: .topTrailing) {
            Button {
                HapticFeedback.light.fire()
                removedLeonMatch = true
            } label: {
                GravityIcon.minusSign.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 12, height: 12)
                    .foregroundStyle(GravityColors.text)
                    .frame(width: GravitySpacing.space20, height: GravitySpacing.space20)
                    .background(GravityColors.bgFill.opacity(0.85), in: Circle())
                    .overlay { Circle().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5) }
                    .shadow(color: GravityColors.shadow200, radius: GravitySpacing.space12, y: GravitySpacing.space4)
            }
            .buttonStyle(PressScaleButtonStyle())
            .offset(x: 5, y: -5)
            .accessibilityLabel("Remove Leon persona")
        }
    }

    private var createPersonaChip: some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            HStack(spacing: 0) {
                GravityIcon.plusSign.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
                    .foregroundStyle(GravityColors.textTertiary)
                    .frame(width: GravitySpacing.space32, height: GravitySpacing.space32)
                Text("Create new persona")
                    .gravityTextStyle(GravityTypography.buttonMedium)
                    .foregroundStyle(GravityColors.text)
            }
            .padding(.leading, GravitySpacing.space4)
            .padding(.trailing, GravitySpacing.space12)
            .frame(height: GravitySpacing.space40)
            .background(GravityColors.bgFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        Color.black.opacity(0.16),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint("Persona creation is not available in this prototype")
    }

    private func sheetIconButton(
        icon: GravityIcon,
        foreground: Color,
        background: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            icon.image
                .resizable()
                .scaledToFit()
                .frame(width: GravitySpacing.space20, height: GravitySpacing.space20)
                .foregroundStyle(foreground)
                .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
                .background(background, in: Circle())
                .overlay { Circle().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5) }
                .shadow(color: GravityColors.shadow100, radius: GravitySpacing.space8, y: GravitySpacing.space2)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct FeedManagerSheet: View {
    @Bindable var store: CustomFeedStore
    let buyerID: String
    let authoredTopics: [BuyerFeedTopic]
    let selectedFeedID: String
    let onCreateNew: () -> Void
    let onDeleteSelectedFeed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: BuyerFeedTopic?
    @GestureState private var draggedFeedID: String?
    @State private var dragOriginOrder: [String] = []
    @State private var dragTargetIndex: Int?
    @State private var dragTranslation: CGFloat = 0

    private let rowStride: CGFloat = 52

    private var feeds: [BuyerFeedTopic] {
        store.managedTopics(for: buyerID, authoredTopics: authoredTopics)
    }

    private var sheetHeight: CGFloat {
        // Keep the 52-point row rhythm and the Figma frame's bottom breathing
        // room without allowing long feed lists to overtake the viewport.
        min(486, max(143, 91 + CGFloat(feeds.count) * 52))
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: GravityRadius.r40,
            bottomLeadingRadius: 52,
            bottomTrailingRadius: 52,
            topTrailingRadius: GravityRadius.r40,
            style: .continuous
        )
    }

    private var draggedRowOffset: CGFloat {
        guard let draggedFeedID,
              let sourceIndex = dragOriginOrder.firstIndex(of: draggedFeedID),
              let targetIndex = dragTargetIndex else {
            return dragTranslation
        }
        return dragTranslation - CGFloat(targetIndex - sourceIndex) * rowStride
    }

    var body: some View {
        managerSurface
            .frame(height: sheetHeight)
            .padding(.horizontal, GravitySpacing.space4)
            .padding(.bottom, GravitySpacing.space4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .background {
                Color.black.opacity(0.18)
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
            }
            .ignoresSafeArea()
            .presentationBackground(.clear)
            .onChange(of: draggedFeedID) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    resetDragState()
                }
            }
            .alert(
                "Delete feed?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { feed in
                Button("Cancel", role: .cancel) {
                    pendingDeletion = nil
                }
                Button("Delete", role: .destructive) {
                    store.deleteFeed(
                        feed.id,
                        for: buyerID,
                        authoredTopics: authoredTopics
                    )
                    if feed.id == selectedFeedID {
                        onDeleteSelectedFeed()
                    }
                    pendingDeletion = nil
                }
            } message: { feed in
                Text("“\(feed.label)” will be removed from your feeds.")
            }
    }

    private var managerSurface: some View {
        List {
            ForEach(feeds) { feed in
                feedRow(feed)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .highPriorityGesture(reorderGesture(for: feed))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDeletion = feed
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            Button {
                HapticFeedback.light.fire()
                onCreateNew()
            } label: {
                HStack(spacing: GravitySpacing.space10) {
                    Circle()
                        .fill(GravityColors.bgFillSecondary)
                        .frame(width: GravitySpacing.space36, height: GravitySpacing.space36)

                    HStack(spacing: GravitySpacing.space4) {
                        Text("Create new")
                        GravityIcon.shopLogo.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: GravitySpacing.space20, height: GravitySpacing.space20)
                        Text("feed")
                    }
                    .gravityTextStyle(GravityTypography.subtitle)
                    .foregroundStyle(GravityColors.textBrand)
                }
                .frame(maxWidth: .infinity, minHeight: GravitySpacing.space36, alignment: .leading)
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 36, bottom: 8, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, GravitySpacing.space12, for: .scrollContent)
        .background(GravityColors.bgFill)
        .clipShape(sheetShape)
        .shadow(color: GravityColors.shadow300, radius: GravitySpacing.space24, y: GravitySpacing.space4)
    }

    private func feedRow(_ feed: BuyerFeedTopic) -> some View {
        let isDragging = draggedFeedID == feed.id

        return HStack(spacing: GravitySpacing.space10) {
            HStack(spacing: GravitySpacing.space4) {
                Image("feed-manager-drag", bundle: .main)
                    .resizable()
                    .frame(width: GravitySpacing.space16, height: GravitySpacing.space16)
                    .accessibilityHidden(true)

                Circle()
                    .fill(GravityColors.bgFillSecondary)
                    .frame(width: GravitySpacing.space36, height: GravitySpacing.space36)
            }

            Text(feed.label)
                .gravityTextStyle(GravityTypography.subtitle)
                .foregroundStyle(GravityColors.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: GravitySpacing.space36)
        .background {
            RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                .fill(isDragging ? GravityColors.bgFill : Color.clear)
        }
        .shadow(
            color: isDragging ? GravityColors.shadow300 : .clear,
            radius: isDragging ? GravitySpacing.space12 : 0,
            y: isDragging ? GravitySpacing.space4 : 0
        )
        .scaleEffect(isDragging ? 1.025 : 1)
        .offset(y: isDragging ? draggedRowOffset : 0)
        .zIndex(isDragging ? 1 : 0)
        .animation(SpringPreset.smooth, value: isDragging)
        .contentShape(Rectangle())
    }

    private func reorderGesture(for feed: BuyerFeedTopic) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18, maximumDistance: 20)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($draggedFeedID) { phase, draggedFeedID, _ in
                switch phase {
                case .first(true), .second(true, _):
                    draggedFeedID = feed.id
                default:
                    break
                }
            }
            .onChanged { phase in
                switch phase {
                case .second(true, let drag?):
                    beginDragging(feed)
                    updateDrag(feed, translation: drag.translation.height)
                default:
                    break
                }
            }
            .onEnded { _ in
                resetDragState()
            }
    }

    private func beginDragging(_ feed: BuyerFeedTopic) {
        guard dragOriginOrder.isEmpty else { return }
        dragOriginOrder = feeds.map(\.id)
        dragTargetIndex = dragOriginOrder.firstIndex(of: feed.id)
        HapticFeedback.medium.fire()
    }

    private func updateDrag(_ feed: BuyerFeedTopic, translation: CGFloat) {
        guard let sourceIndex = dragOriginOrder.firstIndex(of: feed.id),
              !dragOriginOrder.isEmpty else { return }

        dragTranslation = translation
        let rowOffset = Int((translation / rowStride).rounded())
        let targetIndex = min(
            max(sourceIndex + rowOffset, dragOriginOrder.startIndex),
            dragOriginOrder.index(before: dragOriginOrder.endIndex)
        )
        guard targetIndex != dragTargetIndex else { return }

        withAnimation(SpringPreset.smooth) {
            dragTargetIndex = targetIndex
            store.moveFeed(
                feed.id,
                toIndex: targetIndex,
                for: buyerID,
                authoredTopics: authoredTopics
            )
        }
        HapticFeedback.light.fire()
    }

    private func resetDragState() {
        withAnimation(SpringPreset.smooth) { dragTranslation = 0 }
        dragOriginOrder = []
        dragTargetIndex = nil
    }

}

extension HomePage {
    func createFeed(named name: String) {
        guard let placeholderSource = buyerPreview.navigationTopics.first,
              let topic = customFeedStore.createFeed(
                named: name,
                for: buyerPreview.selected.id,
                using: placeholderSource
              ) else { return }

        showsFeedCreator = false
        selectTopic(topic)
    }

    func openFeedCreatorFromManager() {
        showsFeedManager = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            showsFeedCreator = true
        }
    }
}

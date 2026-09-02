import SwiftUI

enum OptionalFeedDestination: String, CaseIterable, Identifiable {
    case following
    case deals

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .following: "Updates from shops you follow"
        case .deals: "Personalized offers and price drops"
        }
    }
    var symbol: String {
        switch self {
        case .following: "person.2"
        case .deals: "tag"
        }
    }
}

@Observable
@MainActor
final class FeedDestinationPreferences {
    static let shared = FeedDestinationPreferences()
    private static let defaultsKey = "enabledOptionalFeedDestinations"
    private(set) var enabledDestinations: Set<OptionalFeedDestination>

    private init() {
        if let stored = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) {
            enabledDestinations = Set(stored.compactMap(OptionalFeedDestination.init(rawValue:)))
        } else {
            enabledDestinations = Set(OptionalFeedDestination.allCases)
        }
    }

    func isEnabled(_ destination: OptionalFeedDestination) -> Bool {
        enabledDestinations.contains(destination)
    }

    func setEnabled(_ enabled: Bool, for destination: OptionalFeedDestination) {
        if enabled { enabledDestinations.insert(destination) }
        else { enabledDestinations.remove(destination) }
        UserDefaults.standard.set(enabledDestinations.map(\.rawValue).sorted(), forKey: Self.defaultsKey)
    }
}

enum FeedContentKind: String, CaseIterable, Identifiable {
    case recommendations
    case merchantCards
    case posts

    var id: String { rawValue }
    var title: String {
        switch self {
        case .recommendations: "Recommendations"
        case .merchantCards: "Merchant cards"
        case .posts: "Posts"
        }
    }
    var subtitle: String {
        switch self {
        case .recommendations: "Topic and product edits"
        case .merchantCards: "Storefront-led assortments"
        case .posts: "Merchant-authored social content"
        }
    }
    var symbol: String {
        switch self {
        case .recommendations: "sparkles.rectangle.stack"
        case .merchantCards: "storefront"
        case .posts: "play.rectangle.on.rectangle"
        }
    }
}

@Observable
@MainActor
final class FeedCompositionPreferences {
    static let shared = FeedCompositionPreferences()
    private static let defaultsKey = "feedContentVisibilityByFeed"
    private var overrides: [String: Bool]

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) ?? [:]
        overrides = stored.compactMapValues { ($0 as? NSNumber)?.boolValue }
    }

    func isEnabled(_ kind: FeedContentKind, in feedID: String) -> Bool {
        overrides[key(kind, feedID)] ?? true
    }

    func setEnabled(_ enabled: Bool, for kind: FeedContentKind, in feedID: String) {
        overrides[key(kind, feedID)] = enabled
        UserDefaults.standard.set(overrides, forKey: Self.defaultsKey)
    }

    func enabledKinds(in feedID: String) -> Set<FeedContentKind> {
        Set(FeedContentKind.allCases.filter { isEnabled($0, in: feedID) })
    }

    private func key(_ kind: FeedContentKind, _ feedID: String) -> String {
        "\(feedID).\(kind.rawValue)"
    }
}

/// Stable identities for cards that can appear in the top-of-feed utility belt.
enum UtilityBeltItem: String, CaseIterable, Identifiable {
    case giftGuide
    case orders
    case buyAgain
    case cart
    case saves
    case keepShopping
    case connectShopEmail
    case connectProviders
    case fiveDollarGift
    case weeklyStoreBonus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .giftGuide: "Start a gift guide"
        case .orders: "Orders"
        case .buyAgain: "Buy again"
        case .cart: "Cart"
        case .saves: "Your saves"
        case .keepShopping: "Keep shopping"
        case .connectShopEmail: "Connect email with Shop"
        case .connectProviders: "Connect Gmail or Outlook"
        case .fiveDollarGift: "$5 gift"
        case .weeklyStoreBonus: "Weekly earning offer"
        }
    }

    var subtitle: String {
        switch self {
        case .giftGuide: "Create ideas for someone you care about"
        case .orders: "Track active deliveries"
        case .buyAgain: "Quickly reorder past purchases"
        case .cart: "Return to your active cart"
        case .saves: "Products you saved"
        case .keepShopping: "Continue recent shopping"
        case .connectShopEmail: "Track more deliveries with Shop"
        case .connectProviders: "Import deliveries from your inbox"
        case .fiveDollarGift: "A limited-time Shop Cash reward"
        case .weeklyStoreBonus: "Earn on qualifying orders"
        }
    }

    var symbol: String {
        switch self {
        case .giftGuide: "gift"
        case .orders: "shippingbox"
        case .buyAgain: "arrow.clockwise"
        case .cart: "cart"
        case .saves: "heart"
        case .keepShopping: "bag"
        case .connectShopEmail: "envelope.badge"
        case .connectProviders: "envelope"
        case .fiveDollarGift: "gift"
        case .weeklyStoreBonus: "dollarsign.arrow.circlepath"
        }
    }
}

@Observable
@MainActor
final class UtilityBeltPreferences {
    static let shared = UtilityBeltPreferences()

    private static let defaultsKey = "enabledUtilityBeltItems"
    private static let giftGuideMigrationKey = "didAddGiftGuideUtilityItem"
    private(set) var enabledItems: Set<UtilityBeltItem>

    private init() {
        if let stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [String] {
            enabledItems = Set(stored.compactMap(UtilityBeltItem.init(rawValue:)))
            if !UserDefaults.standard.bool(forKey: Self.giftGuideMigrationKey) {
                enabledItems.insert(.giftGuide)
                UserDefaults.standard.set(enabledItems.map(\.rawValue).sorted(), forKey: Self.defaultsKey)
                UserDefaults.standard.set(true, forKey: Self.giftGuideMigrationKey)
            }
        } else {
            enabledItems = Set(UtilityBeltItem.allCases)
            UserDefaults.standard.set(true, forKey: Self.giftGuideMigrationKey)
        }
    }

    func isEnabled(_ item: UtilityBeltItem) -> Bool {
        enabledItems.contains(item)
    }

    func setEnabled(_ enabled: Bool, for item: UtilityBeltItem) {
        if enabled {
            enabledItems.insert(item)
        } else {
            enabledItems.remove(item)
        }
        UserDefaults.standard.set(enabledItems.map(\.rawValue).sorted(), forKey: Self.defaultsKey)
    }
}

struct HomeFeedControlsSheet: View {
    let profiles: [BuyerPreviewProfile]
    let selectedProfileID: String
    @Binding var seasonalPlacement: SeasonalPlacement
    @Binding var extendoEnabled: Bool
    @Bindable var beltPreferences: UtilityBeltPreferences
    @Bindable var worldPreferences: WorldPrototypePreferences
    @Bindable var destinationPreferences: FeedDestinationPreferences
    @Bindable var compositionPreferences: FeedCompositionPreferences
    let selectedFeedID: String
    let selectedFeedTitle: String
    let availableContentCounts: [FeedContentKind: Int]
    let onSelectProfile: (BuyerPreviewProfile) -> Void
    let onDisableDestination: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Preview as") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: GravitySpacing.space12
                    ) {
                        ForEach(profiles) { profile in
                            Button { onSelectProfile(profile) } label: {
                                VStack(spacing: GravitySpacing.space6) {
                                    BuyerPreviewAvatar(profile: profile, size: 48)
                                        .overlay {
                                            Circle().strokeBorder(
                                                Color(hex: "#5433EB"),
                                                lineWidth: profile.id == selectedProfileID ? 3 : 0
                                            )
                                        }
                                    Text(profile.name.split(separator: " ").first.map(String.init) ?? profile.name)
                                        .font(.caption)
                                        .fontWeight(profile.id == selectedProfileID ? .semibold : .regular)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, GravitySpacing.space4)
                }

                Section {
                    ForEach(OptionalFeedDestination.allCases) { destination in
                        Toggle(
                            isOn: Binding(
                                get: { destinationPreferences.isEnabled(destination) },
                                set: { enabled in
                                    destinationPreferences.setEnabled(enabled, for: destination)
                                    if !enabled { onDisableDestination(destination.id) }
                                }
                            )
                        ) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.title)
                                    Text(destination.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: destination.symbol)
                                    .foregroundStyle(Color(hex: "#5433EB"))
                            }
                        }
                        .tint(Color(hex: "#5433EB"))
                    }
                } header: {
                    Text("Feed destinations")
                } footer: {
                    Text("Choose which destinations appear in the navigation rail.")
                }

                Section {
                    ForEach(FeedContentKind.allCases) { kind in
                        Toggle(
                            isOn: Binding(
                                get: { compositionPreferences.isEnabled(kind, in: selectedFeedID) },
                                set: { compositionPreferences.setEnabled($0, for: kind, in: selectedFeedID) }
                            )
                        ) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.title)
                                    Text("\(kind.subtitle) · \(availableContentCounts[kind, default: 0]) available")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: kind.symbol)
                                    .foregroundStyle(Color(hex: "#5433EB"))
                            }
                        }
                        .tint(Color(hex: "#5433EB"))
                    }
                } header: {
                    Text("\(selectedFeedTitle) cards")
                } footer: {
                    Text("This mix is saved independently for each feed. Enabled Worlds are managed below.")
                }

                Section("Holiday experience") {
                    Picker("Placement", selection: $seasonalPlacement) {
                        ForEach(SeasonalPlacement.allCases) { placement in
                            Text(placement.label).tag(placement)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    ForEach(WorldPrototypeCatalog.topLevelDefinitions) { definition in
                        Toggle(
                            isOn: Binding(
                                get: { worldPreferences.isEnabled(definition.id) },
                                set: { worldPreferences.setEnabled($0, for: definition.id) }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(definition.title)
                                Text(definition.primaryExperience.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(Color(hex: "#5433EB"))
                    }
                } header: {
                    Text("World prototypes")
                } footer: {
                    Text("Off by default. Enabled Worlds move to the front of Luke’s For You feed.")
                }

                Section {
                    Toggle(isOn: $extendoEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Extendo belt")
                                Text("Pull to expand the cards")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.up.and.down")
                                .foregroundStyle(Color(hex: "#5433EB"))
                        }
                    }
                    .tint(Color(hex: "#5433EB"))

                    ForEach(UtilityBeltItem.allCases) { item in
                        Toggle(
                            isOn: Binding(
                                get: { beltPreferences.isEnabled(item) },
                                set: { beltPreferences.setEnabled($0, for: item) }
                            )
                        ) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: item.symbol)
                                    .foregroundStyle(Color(hex: "#5433EB"))
                            }
                        }
                        .tint(Color(hex: "#5433EB"))
                    }
                } header: {
                    Text("Utility belt")
                } footer: {
                    Text("Choose which cards appear at the top of For You.")
                }
            }
            .navigationTitle("Feed controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Compact promotional cards matching the shared top-of-feed rail geometry.
struct UtilityBeltPromotionCard: View {
    enum Kind: CaseIterable {
        case giftGuide
        case connectShopEmail
        case connectProviders
        case fiveDollarGift
        case weeklyStoreBonus

        var beltItem: UtilityBeltItem {
            switch self {
            case .giftGuide: .giftGuide
            case .connectShopEmail: .connectShopEmail
            case .connectProviders: .connectProviders
            case .fiveDollarGift: .fiveDollarGift
            case .weeklyStoreBonus: .weeklyStoreBonus
            }
        }
    }

    let kind: Kind
    let width: CGFloat
    let height: CGFloat
    var onTap: () -> Void = {}

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    artwork
                        .frame(width: 92, height: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        if let eyebrow {
                            Text(eyebrow)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#5433EB"))
                        }
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .tracking(-0.35)
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)

                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color(hex: "#5433EB"), in: Capsule())
            }
            .padding(12)
            .frame(width: width, height: height)
            .background {
                ZStack {
                    Color.white
                    if kind == .weeklyStoreBonus {
                        Image("utility-weekly-background")
                            .resizable()
                            .scaledToFill()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: UtilityRailMetrics.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: UtilityRailMetrics.cornerRadius, style: .continuous)
                    .strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(buttonTitle)")
    }

    private var title: String {
        switch kind {
        case .giftGuide:
            "Find a gift they’ll love"
        case .connectShopEmail, .connectProviders:
            "Connect your email to track more deliveries with Shop"
        case .fiveDollarGift:
            "Grab your $5 gift"
        case .weeklyStoreBonus:
            "Earn $15 per store"
        }
    }

    private var subtitle: String? {
        switch kind {
        case .giftGuide: "A few details are enough"
        case .fiveDollarGift: "7 days left to claim"
        default: nil
        }
    }

    private var eyebrow: String? {
        switch kind {
        case .giftGuide: "Gift guide"
        case .weeklyStoreBonus: "This week only"
        default: nil
        }
    }

    private var buttonTitle: String {
        switch kind {
        case .giftGuide: "Get started"
        case .connectShopEmail: "Connect now"
        case .connectProviders: "Connect"
        case .fiveDollarGift: "Claim now"
        case .weeklyStoreBonus: "Earn now"
        }
    }

    @ViewBuilder
    private var artwork: some View {
        switch kind {
        case .giftGuide:
            ZStack {
                RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                    .fill(Color(hex: "#EEE8FF"))
                Image(systemName: "gift.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(hex: "#5433EB"))
            }
            .padding(4)
        case .connectShopEmail:
            if let url = Bundle.main.url(
                forResource: "utility-connect-email",
                withExtension: "mp4"
            ) {
                LoopingVideoPlayer(url: url, videoGravity: .resizeAspect)
            }
        case .connectProviders:
            Image("utility-email-providers")
                .resizable()
                .scaledToFit()
        case .fiveDollarGift:
            Image("utility-five-dollar")
                .resizable()
                .scaledToFit()
        case .weeklyStoreBonus:
            Image("utility-weekly-mark")
                .resizable()
                .scaledToFit()
                .padding(6)
        }
    }
}

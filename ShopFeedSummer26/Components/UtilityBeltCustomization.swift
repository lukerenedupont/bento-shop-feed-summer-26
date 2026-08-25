import SwiftUI

/// Stable identities for cards that can appear in the top-of-feed utility belt.
enum UtilityBeltItem: String, CaseIterable, Identifiable {
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
    private(set) var enabledItems: Set<UtilityBeltItem>

    private init() {
        if let stored = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [String] {
            enabledItems = Set(stored.compactMap(UtilityBeltItem.init(rawValue:)))
        } else {
            enabledItems = Set(UtilityBeltItem.allCases)
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
    let onSelectProfile: (BuyerPreviewProfile) -> Void
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
        case connectShopEmail
        case connectProviders
        case fiveDollarGift
        case weeklyStoreBonus

        var beltItem: UtilityBeltItem {
            switch self {
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
        case .connectShopEmail, .connectProviders:
            "Connect your email to track more deliveries with Shop"
        case .fiveDollarGift:
            "Grab your $5 gift"
        case .weeklyStoreBonus:
            "Earn $15 per store"
        }
    }

    private var subtitle: String? {
        kind == .fiveDollarGift ? "7 days left to claim" : nil
    }

    private var eyebrow: String? {
        kind == .weeklyStoreBonus ? "This week only" : nil
    }

    private var buttonTitle: String {
        switch kind {
        case .connectShopEmail: "Connect now"
        case .connectProviders: "Connect"
        case .fiveDollarGift: "Claim now"
        case .weeklyStoreBonus: "Earn now"
        }
    }

    @ViewBuilder
    private var artwork: some View {
        switch kind {
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

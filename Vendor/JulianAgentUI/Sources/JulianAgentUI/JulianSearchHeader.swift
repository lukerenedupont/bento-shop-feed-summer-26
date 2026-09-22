import SwiftUI
import Gravity

/// Uses the original field, UIKit text input, account lockup and close/overflow transition.
public struct JulianSearchHeader: View {
    @Bindable var state: JulianShellState
    @Environment(\.colorScheme) private var colorScheme
    public init(state: JulianShellState) { self.state = state }

    public var body: some View {
        GeometryReader { geometry in
            ShopSearchToolbarControls(
                query: $state.searchQuery, isActive: $state.searchActive,
                placeholder: localizedString("DiscoverySearch.SearchInputPlaceholder"),
                width: max(0, geometry.size.width - 32), showsAvatar: true, showsMore: true,
                colorScheme: colorScheme,
                more: Menu {
                    Button("Utility belt") { state.showsUtilityBeltControls = true }
                    Button(localizedString("NotificationsCenter.Title")) { state.showsServiceNotice = true }
                    Button(localizedString("Account.AccountSettings.Title"), action: state.onAccount)
                } label: {
                    ShopIcon(.overflow, size: .medium)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                        .accessibilityLabel("More")
                        .accessibilityIdentifier("home-more-menu")
                },
                onSubmit: { state.searchActive = false; state.onSelectPage(3) },
                onClose: { state.searchActive = false }, returnContext: nil
            )
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .environment(state)
        .disabled(state.draft.navigation.isDraftPresented || state.isConversationPresented)
    }
}

public struct JulianSearchChip: View {
    let onTap: () -> Void
    public init(onTap: @escaping () -> Void) { self.onTap = onTap }
    public var body: some View {
        ShopFeedSearchQuickLinkPill(actions: .init(onSearch: onTap))
    }
}

public struct JulianFloatingSearch: View {
    let onTap: () -> Void
    public init(onTap: @escaping () -> Void) { self.onTap = onTap }
    public var body: some View { ShopFeedFloatingSearchOverlay(onSearchTapped: onTap) }
}

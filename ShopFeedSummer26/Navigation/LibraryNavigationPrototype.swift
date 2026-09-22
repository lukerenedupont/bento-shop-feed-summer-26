import SwiftUI

/// One restrained Pistons-inspired treatment; the original demo's bar stays unchanged.
struct LibraryBottomNavigation: View {
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                tab(.homeFilled, page: 0, label: "Home")
                tab(.orderFilled, page: 1, label: "Orders")
                tab(.favoritesFilled, page: 5, label: "Favorites")
            }
            .padding(6)
            .background(.white.opacity(0.65), in: Capsule())
            .glassEffect(.regular, in: .capsule)

            Button {
                coordinator.libraryShell.surface = .ask(coordinator.libraryShell.context)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 22, weight: .medium))
                    Text("Ask").font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(.white.opacity(0.65), in: Capsule())
            .glassEffect(.regular.interactive(), in: .capsule)
            .accessibilityLabel("Ask about \(coordinator.libraryShell.context.title)")
            .accessibilityIdentifier("library.ask")

            tab(.cartFilled, page: 4, label: "Cart")
                .padding(6)
                .background(.white.opacity(0.65), in: Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .foregroundStyle(.black)
        .environment(\.colorScheme, .light)
        .padding(.horizontal, 16)
        .padding(.bottom, 28)
    }

    private func tab(_ icon: GravityIcon, page: Int, label: String) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(page)
        } label: {
            icon.image.resizable().scaledToFit().frame(width: 23, height: 23)
                .frame(width: 44, height: 44)
                .background(coordinator.selectedPage == page ? Color.black.opacity(0.08) : .clear, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("tab.\(page)")
        .accessibilityAddTraits(coordinator.selectedPage == page ? .isSelected : [])
    }
}

struct LibraryPersistentSearch: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    /// Includes the gap before the existing category rail; shared with the feed's clearance.
    static let headerHeight: CGFloat = 56

    var body: some View {
        Button {
            coordinator.libraryShell.surface = .search
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 19, weight: .medium))
                Text("Search products and shops").font(.system(size: 16))
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black.opacity(0.65))
            .padding(.horizontal, 16)
            .frame(height: 48)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(.white.opacity(0.78), in: Capsule())
        .glassEffect(.regular.interactive(), in: .capsule)
        .environment(\.colorScheme, .light)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("library.search")
        .accessibilityLabel("Search products and shops")
    }
}

import SwiftUI

/// Favorites tab — placeholder until favoriting state exists in the prototype.
struct FavoritesPage: View {
    var body: some View {
        VStack(spacing: GravitySpacing.space12) {
            GravityIcon.favoritesFilled.image
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(GravityColors.textTertiary)
            Text("No favorites yet")
                .gravityTextStyle(GravityTypography.bodyTitleLarge)
                .foregroundStyle(GravityColors.text)
            Text("Tap the heart on any product to save it here.")
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(GravityColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GravityColors.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { FavoritesPage() }
        .environment(NavigationCoordinator())
}

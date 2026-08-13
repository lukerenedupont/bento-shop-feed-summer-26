import SwiftUI

/// Cart tab — placeholder until cart state exists in the prototype.
struct CartPage: View {
    var body: some View {
        VStack(spacing: GravitySpacing.space12) {
            GravityIcon.cartFilled.image
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundStyle(GravityColors.textTertiary)
            Text("Your cart is empty")
                .gravityTextStyle(GravityTypography.bodyTitleLarge)
                .foregroundStyle(GravityColors.text)
            Text("Things you add will show up here.")
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(GravityColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GravityColors.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { CartPage() }
        .environment(NavigationCoordinator())
}

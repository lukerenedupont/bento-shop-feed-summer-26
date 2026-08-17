import SwiftUI

/// The floating top-left back chip used by topic and subcategory pages,
/// which own their back affordance at the top instead of the bottom bar.
/// Styled to sit over cover imagery, matching the subtopic pills.
struct FloatingBackButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(FeedNavigationStyle.iconFont)
                .foregroundStyle(.black)
                .frame(width: FeedNavigationStyle.controlSize, height: FeedNavigationStyle.controlSize)
                .background(Color.white.opacity(0.94), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel("Back")
    }
}

#Preview {
    FloatingBackButton {}
        .padding()
        .background(Color(hex: "#2C2E24"))
}

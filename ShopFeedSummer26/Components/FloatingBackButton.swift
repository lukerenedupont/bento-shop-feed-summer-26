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
            Image(systemName: "arrow.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.28), in: Circle())
                .overlay { Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
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

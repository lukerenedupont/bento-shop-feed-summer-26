import SwiftUI

/// The shared presentation for both Try your faves sheets — New look and Try
/// on configuration.
///
/// One plate, one header, one footer treatment. The two sheets differ only in
/// what they ask for, so they must not differ in how they look; the icon
/// button and the chip they open from sit side by side in the same top bar.
struct TryFavesSheetPlate<Content: View, Footer: View>: View {
    let title: String
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    /// Live drag translation. Reset only on a spring-back — on a dismissal the
    /// plate is removed, and its state goes with it.
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .gravityTextStyle(GravityTypography.header)
                .foregroundStyle(TryFavesStyle.sheetText)
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.top, GravitySpacing.space20)
                .padding(.bottom, GravitySpacing.space12)

            content()

            footer()
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.top, GravitySpacing.space24)
                .padding(.bottom, GravitySpacing.space20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The same glass as the header controls, at sheet radius.
        .tryFavesGlass(
            in: RoundedRectangle(cornerRadius: TryFavesStyle.sheetRadius, style: .continuous)
        )
        .gravityShadow(GravityShadows.medium)
        // Equal inset on three sides. Measured from the screen edge, not the
        // safe area, or the home indicator would push the plate up and the
        // bottom gap would read as three times the side gap.
        .padding(TryFavesStyle.sheetInset)
        .ignoresSafeArea(edges: .bottom)
        .offset(y: dragOffset)
        .gesture(dismissDrag)
    }

    /// Swipe down to dismiss. The plate tracks the finger, resists upward
    /// travel, and leaves on either distance or a flick — so a short, fast
    /// swipe works as well as a long, slow one.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let travel = value.translation.height
                dragOffset = travel > 0 ? travel : travel / 6
            }
            .onEnded { value in
                let travel = value.translation.height
                let flick = value.predictedEndTranslation.height - travel
                if travel > TryFavesStyle.sheetDismissDistance
                    || flick > TryFavesStyle.sheetDismissFlick {
                    HapticFeedback.light.fire()
                    onDismiss()
                } else {
                    withAnimation(TryFavesStyle.sheetMotion) { dragOffset = 0 }
                }
            }
    }
}

/// Everything a sheet does to the stage behind it: a soft backdrop blur, the
/// lightest dark tint, and the tap-to-dismiss target.
///
/// The blur is a backdrop effect, not `.blur()` on the stage — see
/// `BackdropBlurView`. The stage keeps its exact layout, so opening a sheet
/// moves nothing.
struct TryFavesSheetScrim: View {
    let onDismiss: () -> Void

    var body: some View {
        BackdropBlurView(radius: TryFavesStyle.stageBlur)
            .overlay { Rectangle().fill(TryFavesStyle.sheetScrim) }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }
}

/// A sheet section: a label over its control, at the design's 6pt gap.
struct TryFavesSheetSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space6) {
            Text(title)
                .gravityTextStyle(GravityTypography.bodyTitleLarge)
                .foregroundStyle(TryFavesStyle.sheetText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The sheets' only button. Dark is the committing action, light is the way
/// out or the not-yet-committing one.
struct TryFavesSheetButton: View {
    enum Kind { case dark, light }

    let title: String
    var kind: Kind = .dark
    var isEnabled: Bool = true
    let action: () -> Void

    /// Disabled keeps a filled shape rather than fading the whole button out:
    /// on a glass sheet a faded button dissolves into the plate behind it.
    private var fill: Color {
        guard isEnabled else { return GravityColors.bgOverlayFixedDark40 }
        return kind == .dark ? GravityColors.bgFillFixedDark : GravityColors.bgFillFixedLight
    }

    private var label: Color {
        guard isEnabled else { return GravityColors.textFixedLight.opacity(0.45) }
        return kind == .dark ? GravityColors.textFixedLight : GravityColors.textFixedDark
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            Text(title)
                .gravityTextStyle(GravityTypography.buttonLarge)
                .foregroundStyle(label)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(fill, in: Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

#Preview("Sheet plate") {
    ZStack {
        Image("try-faves-avatar")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
        TryFavesSheetScrim {}
        VStack {
            Spacer()
            TryFavesSheetPlate(title: "Try on configuration", onDismiss: {}) {
                VStack(spacing: GravitySpacing.space16) {
                    TryFavesSheetSection(title: "Describe a change") {
                        Text("Placeholder")
                            .foregroundStyle(TryFavesStyle.sheetTextSecondary)
                    }
                }
                .padding(.horizontal, GravitySpacing.space16)
            } footer: {
                HStack(spacing: GravitySpacing.space8) {
                    TryFavesSheetButton(title: "Close", kind: .light) {}
                    TryFavesSheetButton(title: "Done") {}
                }
            }
        }
    }
}

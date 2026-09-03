import SwiftUI

/// "Try on configuration": the settings behind the stage.
///
/// Three things live here, in order of ambition — build a personal avatar,
/// change the environment the looks are photographed in, and describe a change
/// to appearance or pose. Only the environment applies instantly; it is a
/// plate swap, not a regeneration. The note is folded into the next look, and
/// the personal-avatar flow is still ahead of us.
struct TryFavesConfigurationSheet: View {
    /// The sheet is an overlay on the world page, not a presentation, so it is
    /// handed its own way out.
    let dismiss: () -> Void

    @State private var service = TryFavesLookService.shared

    /// Edited locally so a half-typed note never reaches the generator, and so
    /// Close leaves the stored note untouched.
    @State private var noteDraft: String = ""
    @State private var environmentDraft: TryFavesEnvironment = .seed
    @FocusState private var isEditingNote: Bool

    /// Entry point for the personal-avatar flow, which does not exist yet.
    var onCreateAvatar: () -> Void = {}

    /// Called once the drafts are committed. Environment and appearance are
    /// prompt-only, so the look on screen has to be shot again for either to
    /// show up — the world owns which look that is.
    var onUpdate: () -> Void = {}

    /// Nothing to re-shoot until something actually differs, and a shoot is a
    /// slow, paid round trip — so the action stays disabled rather than
    /// silently doing nothing.
    private var hasChanges: Bool {
        noteDraft.trimmingCharacters(in: .whitespacesAndNewlines) != service.appearanceNote
            || environmentDraft != service.environment
    }

    var body: some View {
        // The world page owns the scrim behind every sheet; this is the plate.
        TryFavesSheetPlate(title: "Try on configuration", onDismiss: dismiss) {
            VStack(spacing: GravitySpacing.space16) {
                personalAvatar
                TryFavesSheetSection(title: "Select your environment") {
                    environmentPicker
                }
                TryFavesSheetSection(title: "Describe a change") {
                    noteField
                }
            }
            .padding(.horizontal, GravitySpacing.space16)
        } footer: {
            HStack(spacing: GravitySpacing.space8) {
                TryFavesSheetButton(title: "Close", kind: .light, action: dismiss)
                TryFavesSheetButton(title: "Update look", isEnabled: hasChanges) { commit() }
            }
        }
        .onAppear {
            noteDraft = service.appearanceNote
            environmentDraft = service.environment
        }
    }

    private func commit() {
        service.appearanceNote = noteDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        service.environment = environmentDraft
        onUpdate()
        dismiss()
    }

    // MARK: - Personal avatar

    /// No well of its own — it is the first of three peer sections, so it
    /// takes the same label, gap, and alignment as the other two.
    private var personalAvatar: some View {
        TryFavesSheetSection(title: "Create your personal avatar") {
            TryFavesSheetButton(title: "Start now", kind: .light) {
                onCreateAvatar()
            }
        }
    }

    // MARK: - Environment

    private var environmentPicker: some View {
        HStack(alignment: .top, spacing: GravitySpacing.space6) {
            ForEach(TryFavesEnvironment.allCases) { environment in
                environmentTile(environment)
            }
        }
    }

    private func environmentTile(_ environment: TryFavesEnvironment) -> some View {
        let isSelected = environmentDraft == environment

        return Button {
            HapticFeedback.selection.fire()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                environmentDraft = environment
            }
        } label: {
            VStack(spacing: GravitySpacing.space4) {
                // Environments without photography stay honest: a plain fill,
                // dimmed and untappable, rather than a broken stage.
                Rectangle()
                    .fill(environment.groundTint)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let plate = environment.plateAssetName {
                            Image(plate)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.white : Color.white.opacity(0.12),
                            lineWidth: isSelected ? 4 : 0.5
                        )
                }
                .gravityShadow(isSelected ? GravityShadows.medium : GravityShadows.small)

                Text(environment.title)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(TryFavesStyle.sheetText)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .opacity(environment.isAvailable ? 1 : 0.4)
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!environment.isAvailable)
        .accessibilityLabel(environment.isAvailable
                            ? environment.title
                            : "\(environment.title), not available yet")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Appearance note

    private var noteField: some View {
        TextField(
            "",
            text: $noteDraft,
            prompt: Text("Change appearance or pose of the avatar")
                .foregroundStyle(GravityColors.textPlaceholder),
            axis: .vertical
        )
        .gravityTextStyle(GravityTypography.bodyLarge)
        .foregroundStyle(GravityColors.textFixedDark)
        .tint(GravityColors.textFixedDark)
        .lineLimit(2, reservesSpace: true)
        .focused($isEditingNote)
        .submitLabel(.done)
        .padding(.horizontal, GravitySpacing.space12)
        .frame(minHeight: 58)
        .background(
            GravityColors.bgFillFixedLight,
            in: RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                .strokeBorder(
                    isEditingNote
                        ? GravityColors.borderInputActive
                        : GravityColors.bgOverlayFixedDark40,
                    lineWidth: isEditingNote ? 1 : 0.5
                )
        }
    }
}

#Preview("Try on configuration") {
    ZStack(alignment: .bottom) {
        Image("try-faves-avatar")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
        TryFavesSheetScrim {}
        TryFavesConfigurationSheet {}
    }
}

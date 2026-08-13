import SwiftUI

/// Composer input card matching the DynamicNav/Input Figma spec.
/// White 85% fill, 28pt corners, glass effect, drop shadow.
/// Drag down to dismiss keyboard with 1:1 interactive tracking.
struct ComposerBar: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Search or ask anything"
    var suggestions: [String] = []
    var onSuggestionTap: (String) -> Void = { _ in }
    var onSubmit: () -> Void = {}

    @State private var dragOffset: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    private let dismissThreshold: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            suggestionPills
            inputCard
        }
        .offset(y: max(dragOffset, 0))
        .opacity(1 - min(dragOffset / dismissThreshold, 1) * 0.5)
        .gesture(dragToDissmissGesture)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            keyboardHeight = KeyboardAnimation.endHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            setKeyboardOffset(0)
        }
    }

    // MARK: - Suggestion Pills

    @ViewBuilder
    private var suggestionPills: some View {
        if !suggestions.isEmpty && text.isEmpty {
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                Text("Suggestions")
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/Search/ComposerBar.swift:foregroundStyle:_:43:38", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                    .padding([.leading, .bottom, .trailing], GravitySpacing.space4)

                ForEach(suggestions, id: \.self) { prompt in
                    Button {
                        HapticFeedback.light.fire()
                        onSuggestionTap(prompt)
                    } label: {
                        Text(prompt)
                            .gravityTextStyle(GravityTypography.buttonMedium)
                            .foregroundStyle(PurlTune.token("Components/Search/ComposerBar.swift:foregroundStyle:_:53:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, PurlTune.token("Components/Search/ComposerBar.swift:padding:_:55:51", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                            .padding(.vertical, PurlTune.token("Components/Search/ComposerBar.swift:padding:_:56:49", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                            .background(GravityColors.bgOverlayFixedLight75, in: Capsule())
                            .glassEffect(.regular)
                            .overlay(
                                Capsule().stroke(GravityColors.borderSecondary, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
                }
            }
            .padding(.horizontal, PurlTune.token("Components/Search/ComposerBar.swift:padding:_:66:35", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 4) {
            // Text field
            HStack {
                TextField(placeholder, text: $text, prompt: Text(placeholder).foregroundStyle(PurlTune.token("Components/Search/ComposerBar.swift:foregroundStyle:_:76:95", default: GravityColors.textPlaceholder, options: GravityColors.purlTuneColorOptions)), axis: .vertical)
                    .gravityTextStyle(GravityTypography.bodyLarge)
                    .foregroundStyle(PurlTune.token("Components/Search/ComposerBar.swift:foregroundStyle:_:78:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .tracking(-1)
                    .focused($isFocused)
                    .lineLimit(1...4)
                    .submitLabel(.send)
                    .onSubmit {
                        if !text.isEmpty { onSubmit() }
                    }
            }
            .padding(.horizontal, PurlTune.value("Components/Search/ComposerBar.swift:padding:_:87:35", default: 10))
            .padding(.vertical, PurlTune.value("Components/Search/ComposerBar.swift:padding:_:88:33", default: 4))
            .frame(minHeight: PurlTune.value("Components/Search/ComposerBar.swift:frame:minHeight:89:31", default: 42))

            // Controls row
            HStack {
                addButton
                Spacer()
                sendButton
            }
            .frame(height: PurlTune.value("Components/Search/ComposerBar.swift:frame:height:97:28", default: 40))
        }
        .padding(PurlTune.value("Components/Search/ComposerBar.swift:padding:_:99:18", default: 8))
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(PurlTune.value("Components/Search/ComposerBar.swift:opacity:_:102:38", default: 0.85)))
        )
        .glassEffect(in: .rect(cornerRadius: 28.0))
    }

    // MARK: - Buttons

    private var addButton: some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            GravityIcon.plusSign.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/ComposerBar.swift:frame:width:116:31", default: 20), height: PurlTune.value("Components/Search/ComposerBar.swift:frame:height:116:126", default: 20))
                .foregroundStyle(PurlTune.token("Components/Search/ComposerBar.swift:foregroundStyle:_:117:34", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/ComposerBar.swift:frame:width:118:31", default: 40), height: PurlTune.value("Components/Search/ComposerBar.swift:frame:height:118:126", default: 40))
                .background(
                    Circle().strokeBorder(GravityColors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
    }

    private var sendButton: some View {
        Button {
            HapticFeedback.light.fire()
            if !text.isEmpty { onSubmit() }
        } label: {
            GravityIcon.arrowRight.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/ComposerBar.swift:frame:width:134:31", default: 20), height: PurlTune.value("Components/Search/ComposerBar.swift:frame:height:134:126", default: 20))
                .foregroundStyle(.white)
                .frame(width: PurlTune.value("Components/Search/ComposerBar.swift:frame:width:136:31", default: 40), height: PurlTune.value("Components/Search/ComposerBar.swift:frame:height:136:126", default: 40))
                .background(
                    text.isEmpty
                        ? GravityColors.bgOverlayFixedDark10
                        : GravityColors.bgFillBrand,
                    in: Circle()
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .shadow(
            color: text.isEmpty ? .clear : Color(red: 0x45/255, green: 0x24/255, blue: 0xDB/255).opacity(PurlTune.value("Components/Search/ComposerBar.swift:opacity:_:146:106", default: 0.34)),
            radius: 8,
            x: 0,
            y: 4
        )
        .animation(text.isEmpty ? .easeOut(duration: 0.1) : .easeIn(duration: 0.25), value: text.isEmpty)
    }

    // MARK: - Drag to Dismiss

    private var dragToDissmissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dy = max(value.translation.height, 0)
                dragOffset = dy
                if keyboardHeight > 0 {
                    setKeyboardOffset(dy)
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold {
                    HapticFeedback.light.fire()
                    isFocused = false
                    text = ""
                } else {
                    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                        setKeyboardOffset(0)
                    }
                }
                withAnimation(.spring(response: PurlTune.value("Components/Search/ComposerBar.swift:spring:response:175:49", default: 0.3), dampingFraction: PurlTune.value("Components/Search/ComposerBar.swift:spring:dampingFraction:175:158", default: 0.8))) {
                    dragOffset = 0
                }
            }
    }
}

// MARK: - Keyboard Window Offset

/// Finds the keyboard window and offsets it vertically for 1:1 interactive dismissal.
private func setKeyboardOffset(_ offset: CGFloat) {
    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for window in windowScene.windows {
            let typeName = String(describing: type(of: window))
            if typeName.contains("UIRemoteKeyboardWindow") || typeName.contains("UITextEffectsWindow") {
                window.transform = CGAffineTransform(translationX: 0, y: offset)
            }
        }
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    ComposerBar(
        text: $text,
        isFocused: $focused,
        suggestions: [
            "Gift ideas under $50",
            "Where is my order?",
            "Cozy weekend sweaters",
        ]
    )
    .padding()
    .background(PurlTune.token("Components/Search/ComposerBar.swift:background:_:210:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

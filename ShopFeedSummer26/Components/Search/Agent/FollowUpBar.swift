import SwiftUI

/// Bottom bar for asking follow-up questions in a conversation.
/// Simple pill with TextField inside. Tap to type, keyboard raises bar.
struct FollowUpBar: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var isNavigatedDeep: Bool = false
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var keyboardHeight: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var pillPressed: Bool = false
    private let dismissThreshold: CGFloat = 60

    var body: some View {
        HStack(spacing: 8) {
            // Back button — morphs in from the pill when navigated deep
            if isNavigatedDeep && !isFocused {
                Button {
                    HapticFeedback.light.fire()
                    onBack?()
                } label: {
                    GravityIcon.leftChevron.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:29:39", default: 20), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:29:139", default: 20))
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:foregroundStyle:_:30:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:31:39", default: 40), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:31:139", default: 40))
                        .padding(PurlTune.value("Components/Search/Agent/FollowUpBar.swift:padding:_:32:34", default: 6))
                        .background(
                            Circle()
                                .strokeBorder(GravityColors.border, lineWidth: 0.5)
                                .fill(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:fill:_:36:39", default: GravityColors.bgOverlayFixedLight10, options: GravityColors.purlTuneColorOptions))
                        )
                        .glassEffect(.regular)
                        .gravityShadow(GravityShadows.small)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.95))
                .transition(.scale(scale: 0.5, anchor: .trailing).combined(with: .opacity))
            }

            inputPill
            if !isFocused {
                closePill
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:51:38", default: 0.25), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:51:153", default: 0.85)), value: isFocused)
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:52:38", default: 0.35), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:52:153", default: 0.8)), value: isNavigatedDeep)
        .padding(.horizontal, !isFocused ? GravitySpacing.space16 : GravitySpacing.space12)
        .padding(.top, PurlTune.token("Components/Search/Agent/FollowUpBar.swift:padding:_:54:24", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - 24 : 0)
        .background(
            LinearGradient(
                colors: [GravityColors.bg.opacity(PurlTune.value("Components/Search/Agent/FollowUpBar.swift:opacity:_:58:51", default: 0)), GravityColors.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: max(dragOffset, 0))
        .opacity(1 - min(dragOffset / dismissThreshold, 1) * 0.5)
        .gesture(isFocused ? dragToDissmissGesture : nil)
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:67:38", default: 0.3), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:67:152", default: 0.85)), value: text.isEmpty)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            let anim = KeyboardAnimation.animation(from: notification)
            withAnimation(anim) {
                keyboardHeight = KeyboardAnimation.endHeight(from: notification)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            let anim = KeyboardAnimation.animation(from: notification)
            withAnimation(anim) {
                keyboardHeight = 0
            }
        }
    }

    // MARK: - Input Pill

    private var inputPill: some View {
        VStack(spacing: isFocused ? 4 : 0) {
            // Text field row
            HStack(spacing: 8) {
                TextField("Ask a follow-up", text: $text, prompt: Text("Ask a follow-up").foregroundStyle(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:foregroundStyle:_:88:107", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions)))
                    .gravityTextStyle(GravityTypography.bodyLarge)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:foregroundStyle:_:90:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { submit() }

                if !isFocused && !text.isEmpty {
                    Button {
                        HapticFeedback.light.fire()
                        submit()
                    } label: {
                        GravityIcon.arrowRight.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:103:43", default: 18), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:103:144", default: 18))
                            .foregroundStyle(.white)
                            .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:105:43", default: 36), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:105:144", default: 36))
                            .background(GravityColors.bgFillBrand, in: Circle())
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.95))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, isFocused ? 10 : GravitySpacing.space16)
            .frame(minHeight: isFocused ? 42 : 56)

            // Controls row — only when focused
            if isFocused {
                HStack {
                    addButton
                    Spacer()
                    sendButton
                }
                .frame(height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:122:32", default: 40))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(isFocused ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: isFocused ? 28 : 999, style: .continuous)
                .fill(Color.white.opacity(isFocused ? 1 : 0.1))
        )
        .glassEffect(in: .rect(cornerRadius: isFocused ? 28 : 999))
        .overlay(
            RoundedRectangle(cornerRadius: isFocused ? 28 : 999, style: .continuous)
                .strokeBorder(GravityColors.border, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
        .scaleEffect(!isFocused && pillPressed ? 0.97 : 1.0)
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:138:38", default: 0.2), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:138:153", default: 0.7)), value: pillPressed)
        .simultaneousGesture(
            isFocused ? nil : DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pillPressed { pillPressed = true }
                }
                .onEnded { _ in
                    pillPressed = false
                }
        )
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:148:38", default: 0.25), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:148:154", default: 0.85)), value: isFocused)
    }

    // MARK: - Composer Buttons

    private var addButton: some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            GravityIcon.plusSign.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:160:31", default: 20), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:160:132", default: 20))
                .foregroundStyle(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:foregroundStyle:_:161:34", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:162:31", default: 40), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:162:132", default: 40))
                .background(
                    Circle().strokeBorder(GravityColors.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
    }

    private var sendButton: some View {
        Button {
            HapticFeedback.light.fire()
            submit()
        } label: {
            GravityIcon.arrowRight.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:178:31", default: 20), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:178:132", default: 20))
                .foregroundStyle(.white)
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:180:31", default: 40), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:180:132", default: 40))
                .background(
                    text.isEmpty
                        ? GravityColors.bgOverlayFixedDark10
                        : GravityColors.bgFillBrand,
                    in: Circle()
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .shadow(
            color: text.isEmpty ? .clear : Color(red: 0x45/255, green: 0x24/255, blue: 0xDB/255).opacity(PurlTune.value("Components/Search/Agent/FollowUpBar.swift:opacity:_:190:106", default: 0.34)),
            radius: 8,
            x: 0,
            y: 4
        )
        .animation(text.isEmpty ? .easeOut(duration: 0.1) : .easeIn(duration: 0.25), value: text.isEmpty)
    }

    // MARK: - Close Pill

    private var closePill: some View {
        Button {
            HapticFeedback.light.fire()
            onDismiss()
        } label: {
            GravityIcon.cross.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:208:31", default: 20), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:208:132", default: 20))
                .foregroundStyle(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:foregroundStyle:_:209:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .frame(width: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:width:210:31", default: 40), height: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:frame:height:210:132", default: 40))
                .padding(PurlTune.value("Components/Search/Agent/FollowUpBar.swift:padding:_:211:26", default: 6))
                .background(
                    Circle()
                        .strokeBorder(GravityColors.border, lineWidth: 0.5)
                        .fill(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:fill:_:215:31", default: GravityColors.bgOverlayFixedLight10, options: GravityColors.purlTuneColorOptions))
                )
                .glassEffect(.regular)
                .gravityShadow(GravityShadows.small)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
    }

    // MARK: - Actions

    private func submit() {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        text = ""
        isFocused = false
        onSubmit(query)
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
                    setKeyboardOffset(0)
                } else {
                    UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                        setKeyboardOffset(0)
                    }
                }
                withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:response:254:49", default: 0.3), dampingFraction: PurlTune.value("Components/Search/Agent/FollowUpBar.swift:spring:dampingFraction:254:164", default: 0.8))) {
                    dragOffset = 0
                }
            }
    }
}

// MARK: - Keyboard Window Offset

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
    FollowUpBar(
        text: $text,
        isFocused: $focused,
        isNavigatedDeep: false,
        onSubmit: { _ in },
        onDismiss: {},
        onBack: nil
    )
    .padding()
    .background(PurlTune.token("Components/Search/Agent/FollowUpBar.swift:background:_:287:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

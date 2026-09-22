import SwiftUI

public enum ShopTextFieldClearButtonMode: Sendable {
    case always
    case auto
    case never
}

enum ShopTextFieldTrailingContent: Equatable {
    case clearButton
    case errorIcon
    case customIcon(GravityIconName)
    case none
}

public enum ShopTextFieldTitlePlacement: Sendable {
    case aboveField
    case insideField
}

enum ShopTextFieldTitleRendering: Equatable {
    case title
    case placeholderOnly
}

func shopTextFieldTitleRendering(
    placement: ShopTextFieldTitlePlacement,
    isEmpty: Bool,
    isFocused: Bool,
    isVoiceOverEnabled: Bool
) -> ShopTextFieldTitleRendering {
    guard placement == .insideField else { return .title }
    return isFocused || !isEmpty || isVoiceOverEnabled ? .title : .placeholderOnly
}

func shopTextFieldPrompt(
    title: String,
    placeholder: String?,
    placement: ShopTextFieldTitlePlacement,
    titleRendering: ShopTextFieldTitleRendering
) -> String {
    guard placement == .insideField else { return placeholder ?? title }
    return titleRendering == .title ? (placeholder ?? "") : title
}

let shopTextFieldInsideTitleMinHeight: CGFloat = 58
let shopTextFieldDefaultMinHeight: CGFloat = 48

func shopTextFieldTrailingContent(
    clearButtonMode: ShopTextFieldClearButtonMode,
    text: String,
    isFocused: Bool,
    isError: Bool,
    trailingIcon: GravityIconName?
) -> ShopTextFieldTrailingContent {
    if clearButtonMode == .always || (clearButtonMode == .auto && !text.isEmpty && isFocused) {
        return .clearButton
    }
    if isError {
        return .errorIcon
    }
    if let trailingIcon {
        return .customIcon(trailingIcon)
    }
    return .none
}

let shopTextFieldClearButtonHorizontalOffset = GravitySpacing.space8

func shopTextFieldClearButtonIdentifier(testID: String?) -> String {
    testID.map { "\($0)-clear-button" } ?? "clear-button"
}

func shopTextFieldClearButtonAccessibilityLabel(
    fieldAccessibilityLabel: String,
    bundle: Bundle = .gravityResources
) -> String {
    String(
        format: NSLocalizedString("TextField.ClearA11yLabel", bundle: bundle, comment: ""),
        fieldAccessibilityLabel
    )
}

public struct ShopTextField: View {
    private let title: String
    private let titlePlacement: ShopTextFieldTitlePlacement
    private let placeholder: String?
    private let leadingIcon: GravityIconName?
    private let trailingIcon: GravityIconName?
    private let clearButtonMode: ShopTextFieldClearButtonMode
    private let accessibilityLabel: String
    private let titleAccessibilityHidden: Bool
    private let testID: String?
    private let isDisabled: Bool
    private let isError: Bool
    private let keyboardType: UIKeyboardType
    private let autocorrectionDisabled: Bool
    private let submitLabel: SubmitLabel
    private let axis: Axis
    private let focusBinding: FocusState<Bool>.Binding?
    private let onSubmit: () -> Void

    @Binding private var text: String
    @FocusState private var isInternallyFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled

    public init(
        _ title: String,
        text: Binding<String>,
        titlePlacement: ShopTextFieldTitlePlacement = .aboveField,
        placeholder: String? = nil,
        leadingIcon: GravityIconName? = nil,
        trailingIcon: GravityIconName? = nil,
        clearButtonMode: ShopTextFieldClearButtonMode = .auto,
        accessibilityLabel: String? = nil,
        titleAccessibilityHidden: Bool = false,
        testID: String? = nil,
        isDisabled: Bool = false,
        isError: Bool = false,
        keyboardType: UIKeyboardType = .default,
        autocorrectionDisabled: Bool = false,
        submitLabel: SubmitLabel = .done,
        axis: Axis = .horizontal,
        isFocused: FocusState<Bool>.Binding? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.title = title
        self.titlePlacement = titlePlacement
        self._text = text
        self.placeholder = placeholder
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.clearButtonMode = clearButtonMode
        self.accessibilityLabel = accessibilityLabel ?? title
        self.titleAccessibilityHidden = titleAccessibilityHidden
        self.testID = testID
        self.isDisabled = isDisabled
        self.isError = isError
        self.keyboardType = keyboardType
        self.autocorrectionDisabled = autocorrectionDisabled
        self.submitLabel = submitLabel
        self.axis = axis
        self.focusBinding = isFocused
        self.onSubmit = onSubmit
    }

    public var body: some View {
        switch titlePlacement {
        case .aboveField:
            VStack(alignment: .leading, spacing: GravitySpacing.space6) {
                titleText
                inputRow
                    .padding(.horizontal, GravitySpacing.space12)
                    .frame(minHeight: shopTextFieldDefaultMinHeight)
                    .fieldContainer(borderColor: borderColor)
            }
        case .insideField:
            VStack(alignment: .leading, spacing: 0) {
                if titleRendering == .title {
                    titleText
                }
                inputRow
            }
            .padding(.horizontal, GravitySpacing.space12)
            .padding(.vertical, GravitySpacing.space4)
            .frame(minHeight: shopTextFieldInsideTitleMinHeight)
            .fieldContainer(borderColor: borderColor)
        }
    }

    private var titleText: some View {
        ShopText(title, style: .caption, color: isError ? GravityColor.textCritical : GravityColor.textSecondary)
            .accessibilityHidden(titleAccessibilityHidden)
    }

    private var inputRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            if let leadingIcon {
                ShopIcon(
                    leadingIcon,
                    size: .medium,
                    color: isDisabled ? GravityColor.textPlaceholder : GravityColor.textSecondary
                )
                .accessibilityHidden(true)
            }

            SwiftUI.TextField(prompt, text: $text, axis: axis)
                .font(GravityTextStyle.bodyLarge.font)
                .kerning(GravityTextStyle.bodyLarge.kerning)
                .foregroundStyle(isDisabled ? GravityColor.textPlaceholder : GravityColor.text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .focused(resolvedFocusBinding)
                .disabled(isDisabled)
                .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
                .shopOptionalAccessibilityIdentifier(testID)

            trailingContent
        }
    }

    private var prompt: String {
        shopTextFieldPrompt(
            title: title,
            placeholder: placeholder,
            placement: titlePlacement,
            titleRendering: titleRendering
        )
    }

    private var titleRendering: ShopTextFieldTitleRendering {
        shopTextFieldTitleRendering(
            placement: titlePlacement,
            isEmpty: text.isEmpty,
            isFocused: isFocused,
            isVoiceOverEnabled: isVoiceOverEnabled
        )
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch shopTextFieldTrailingContent(
            clearButtonMode: clearButtonMode,
            text: text,
            isFocused: isFocused,
            isError: isError,
            trailingIcon: trailingIcon
        ) {
        case .clearButton:
            ShopIconButton(
                .crossCircleFilled,
                accessibilityLabel: shopTextFieldClearButtonAccessibilityLabel(
                    fieldAccessibilityLabel: accessibilityLabel
                ),
                variant: .plain,
                size: .large,
                foregroundColor: GravityColor.textPlaceholder,
                action: { text = "" }
            )
            .offset(x: shopTextFieldClearButtonHorizontalOffset)
            .accessibilityIdentifier(shopTextFieldClearButtonIdentifier(testID: testID))
        case .errorIcon:
            ShopIcon(.exclamationCircleFilled, size: .xLarge, color: GravityColor.textCritical)
                .accessibilityHidden(true)
        case let .customIcon(icon):
            ShopIcon(
                icon,
                size: .medium,
                color: isDisabled ? GravityColor.textPlaceholder : GravityColor.textSecondary
            )
            .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    private var resolvedFocusBinding: FocusState<Bool>.Binding {
        focusBinding ?? $isInternallyFocused
    }

    private var isFocused: Bool {
        focusBinding?.wrappedValue ?? isInternallyFocused
    }

    private var borderColor: Color {
        if isError { return GravityColor.borderCritical }
        if isDisabled { return GravityColor.borderSecondary }
        return GravityColor.borderInput
    }
}

private extension View {
    func fieldContainer(borderColor: Color) -> some View {
        background(GravityColor.bgFill)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.radius12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    @ViewBuilder
    func shopOptionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

#Preview("ShopTextField") {
    VStack(spacing: GravitySpacing.space16) {
        ShopTextField("Email", text: .constant(""), placeholder: "you@example.com", leadingIcon: .email)
        ShopTextField("Search", text: .constant("Shop"), leadingIcon: .search, clearButtonMode: .always)
        ShopTextField("Error", text: .constant(""), isError: true)
        ShopTextField("Custom", text: .constant(""), trailingIcon: .website, clearButtonMode: .never)
        ShopTextField("Inside title, empty", text: .constant(""), titlePlacement: .insideField)
        ShopTextField("Inside title, filled", text: .constant("1Z999"), titlePlacement: .insideField)
    }
    .padding()
}

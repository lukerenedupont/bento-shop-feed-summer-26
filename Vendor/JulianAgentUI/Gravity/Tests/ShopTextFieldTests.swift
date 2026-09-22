import Testing

@testable import Gravity

struct ShopTextFieldTests {
    @Test
    func clearButtonMatchesInlineIconSizingAndPlacement() {
        #expect(ShopIconButtonSize.large.iconSize == .medium)
        #expect(shopTextFieldClearButtonHorizontalOffset == GravitySpacing.space8)
    }

    @Test
    func autoClearButtonRequiresFocusAndText() {
        #expect(trailing(mode: .auto, text: "Shop", isFocused: true) == .clearButton)
        #expect(trailing(mode: .auto, text: "", isFocused: true) == .none)
        #expect(trailing(mode: .auto, text: "Shop", isFocused: false) == .none)
    }

    @Test
    func clearButtonWinsOverErrorInAlwaysAndAutoModes() {
        #expect(trailing(mode: .always, text: "", isFocused: false, isError: true) == .clearButton)
        #expect(trailing(mode: .auto, text: "Shop", isFocused: true, isError: true) == .clearButton)
    }

    @Test
    func clearButtonPresentationUsesGravityLocalizationAndDerivedIdentifiers() {
        #expect(
            shopTextFieldClearButtonAccessibilityLabel(fieldAccessibilityLabel: "Email address") ==
                "Clear Email address"
        )
        #expect(shopTextFieldClearButtonIdentifier(testID: "email-field") == "email-field-clear-button")
        #expect(shopTextFieldClearButtonIdentifier(testID: nil) == "clear-button")
    }

    @Test
    func errorWinsOverCustomIconWhenClearButtonIsHidden() {
        #expect(
            trailing(mode: .never, text: "Shop", isFocused: true, isError: true, trailingIcon: .search) == .errorIcon
        )
    }

    @Test
    func aboveFieldPlacementAlwaysRendersTheTitle() {
        #expect(titleRendering(placement: .aboveField, isEmpty: true) == .title)
        #expect(titleRendering(placement: .aboveField, isEmpty: false) == .title)
    }

    @Test
    func insideFieldPlacementDropsTheTitleWhileEmptyAndUnfocused() {
        #expect(titleRendering(placement: .insideField, isEmpty: true) == .placeholderOnly)
        #expect(titleRendering(placement: .insideField, isEmpty: true, isFocused: true) == .title)
        #expect(titleRendering(placement: .insideField, isEmpty: false) == .title)
    }

    @Test
    func insideFieldPlacementAlwaysRendersTheTitleForVoiceOver() {
        #expect(
            titleRendering(placement: .insideField, isEmpty: true, isVoiceOverEnabled: true) == .title
        )
    }

    @Test
    func aboveFieldPromptFallsBackToTheTitle() {
        #expect(prompt(placement: .aboveField, titleRendering: .title) == "Tracking number")
        #expect(prompt(placement: .aboveField, placeholder: "1Z999", titleRendering: .title) == "1Z999")
    }

    @Test
    func insideFieldPromptDoesNotRepeatARenderedTitle() {
        #expect(prompt(placement: .insideField, titleRendering: .title) == "")
        #expect(prompt(placement: .insideField, placeholder: "1Z999", titleRendering: .title) == "1Z999")
    }

    @Test
    func insideFieldPromptStandsInForTheTitleWhileEmptyAndUnfocused() {
        #expect(prompt(placement: .insideField, titleRendering: .placeholderOnly) == "Tracking number")
        #expect(
            prompt(placement: .insideField, placeholder: "1Z999", titleRendering: .placeholderOnly)
                == "Tracking number"
        )
    }

    @Test
    func insideFieldContainerMatchesRNFormFieldHeight() {
        #expect(shopTextFieldInsideTitleMinHeight == 58)
        #expect(shopTextFieldDefaultMinHeight == 48)
    }

    @Test
    func customIconRemainsTheFallback() {
        #expect(trailing(mode: .never, trailingIcon: .search) == .customIcon(.search))
        #expect(trailing(mode: .never) == .none)
    }

    private func titleRendering(
        placement: ShopTextFieldTitlePlacement,
        isEmpty: Bool,
        isFocused: Bool = false,
        isVoiceOverEnabled: Bool = false
    ) -> ShopTextFieldTitleRendering {
        shopTextFieldTitleRendering(
            placement: placement,
            isEmpty: isEmpty,
            isFocused: isFocused,
            isVoiceOverEnabled: isVoiceOverEnabled
        )
    }

    private func prompt(
        placement: ShopTextFieldTitlePlacement,
        placeholder: String? = nil,
        titleRendering: ShopTextFieldTitleRendering
    ) -> String {
        shopTextFieldPrompt(
            title: "Tracking number",
            placeholder: placeholder,
            placement: placement,
            titleRendering: titleRendering
        )
    }

    private func trailing(
        mode: ShopTextFieldClearButtonMode,
        text: String = "",
        isFocused: Bool = false,
        isError: Bool = false,
        trailingIcon: GravityIconName? = nil
    ) -> ShopTextFieldTrailingContent {
        shopTextFieldTrailingContent(
            clearButtonMode: mode,
            text: text,
            isFocused: isFocused,
            isError: isError,
            trailingIcon: trailingIcon
        )
    }
}

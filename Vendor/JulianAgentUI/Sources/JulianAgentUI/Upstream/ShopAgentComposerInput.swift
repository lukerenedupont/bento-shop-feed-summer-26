import SwiftUI
import Gravity
import UIKit

enum ShopAgentComposerMotion {
    static let stateChangeDuration: TimeInterval = 0.32
    static let stateChange: Animation = .timingCurve(0.2, 0, 0, 1, duration: stateChangeDuration)
}

enum ShopAgentComposerAttachmentLane: Equatable {
    case empty
    case images
    case context
    case contextAndImages
}

func shopAgentComposerAttachmentLane(
    hasContextSummary: Bool,
    imageAttachmentCount: Int
) -> ShopAgentComposerAttachmentLane {
    switch (hasContextSummary, imageAttachmentCount > 0) {
    case (false, false): .empty
    case (false, true): .images
    case (true, false): .context
    case (true, true): .contextAndImages
    }
}

func shopAgentComposerPlaceholder(
    defaultPlaceholder: String,
    singleAttachmentPlaceholder: String,
    multipleAttachmentPlaceholder: String,
    hasContextSummary: Bool,
    imageAttachmentCount: Int
) -> String {
    let attachmentCount = imageAttachmentCount + (hasContextSummary ? 1 : 0)
    switch attachmentCount {
    case 0: return defaultPlaceholder
    case 1: return singleAttachmentPlaceholder
    default: return multipleAttachmentPlaceholder
    }
}

private enum ShopAgentComposerMetrics {
    static let buttonSize: CGFloat = GravitySpacing.space40
    static let expandedTextInputMinHeight: CGFloat = buttonSize + GravitySpacing.space8
    static let textInputMaxLines = 3

    /// RN parity: in the inline row the text field carries no horizontal padding, so the only
    /// gap between the add-context button and the caret is the row's `space8` spacing. Adding
    /// padding here on top of that spacing pushes the caret ~20pt off the button instead of 8pt.
    /// See `AgentComposerBar.tsx` (`styles.singleLineTextInput` sets `paddingVertical` only).
    static let compactTextInputHorizontalPadding: CGFloat = GravitySpacing.space0

    /// RN parity: only the context-row layout, where the field sits on its own row above the
    /// buttons, adds horizontal padding (`styles.contextRowTextInput`).
    static let expandedTextInputHorizontalPadding: CGFloat = GravitySpacing.space12
}

let shopAgentComposerInputMaxLength = 2_048

struct ShopAgentComposerTextInputUpdate {
    let query: String
    let shouldSubmit: Bool
}

func shopAgentComposerTextInputUpdate(
    newValue: String,
    canSubmit: Bool
) -> ShopAgentComposerTextInputUpdate {
    let queryWithoutLineBreaks = newValue
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\n", with: "")
    let insertedLineBreak = queryWithoutLineBreaks != newValue

    return ShopAgentComposerTextInputUpdate(
        query: queryWithoutLineBreaks,
        shouldSubmit: insertedLineBreak &&
            (canSubmit || queryWithoutLineBreaks.contains { !$0.isWhitespace })
    )
}


import SwiftUI
import Gravity
import UIKit

enum ShopAgentComposerAttachmentPickerSource: String, Identifiable, Sendable {
    case library
    case camera
    case attach

    var id: String { rawValue }
}


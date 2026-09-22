import SwiftUI

public enum GravityIconRenderingStyle: Equatable, Sendable {
    case template
    case original

    public var templateRenderingMode: Image.TemplateRenderingMode {
        switch self {
        case .template:
            .template
        case .original:
            .original
        }
    }
}

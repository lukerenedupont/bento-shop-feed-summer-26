import CoreText
import Foundation
import SwiftUI

public enum GravityFonts {
    public static let regular = "GTStandard-MRegular"
    public static let medium = "GTStandard-MMedium"
    public static let semibold = "GTStandard-MSemibold"
    public static let bold = "GTStandard-MBold"
    public static let expressiveBold = "GTStandard-LHeavy"

    private static let fontFiles = [
        "GTStandard-LHeavy.otf",
        "GTStandard-MBold.otf",
        "GTStandard-MMedium.otf",
        "GTStandard-MRegular.otf",
        "GTStandard-MSemibold.otf",
    ]

    nonisolated(unsafe) private static var didRegister = false

    public static func registerIfNeeded() {
        guard !didRegister else { return }

        let bundle = Bundle.gravityResources
        fontFiles.forEach { fileName in
            guard let url = bundle.url(forResource: fileName, withExtension: nil) else {
                return
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }

        didRegister = true
    }

    public static func font(
        name: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        registerIfNeeded()
        return .custom(name, size: size, relativeTo: textStyle)
    }
}

private final class BundleToken {}

public extension Bundle {
#if SWIFT_PACKAGE
    static let gravityResources = Bundle.module
#else
    static let gravityResources = Bundle(for: BundleToken.self)
#endif
}

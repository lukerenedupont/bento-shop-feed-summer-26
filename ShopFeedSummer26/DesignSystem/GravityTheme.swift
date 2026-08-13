import SwiftUI
import CoreText

/// Top-level Gravity theme providing access to all design tokens.
struct GravityTheme {
    let colors = GravityColors.self

    static let current = GravityTheme()

    /// Register all bundled fonts at runtime. Call once from App init.
    static func registerFonts() {
        let extensions = ["otf", "ttf"]
        for ext in extensions {
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "Fonts") {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
            // Also check without subdirectory in case Xcode flattens them
            if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in urls {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }
}

// MARK: - Environment Integration

private struct GravityThemeKey: EnvironmentKey {
    static let defaultValue = GravityTheme.current
}

extension EnvironmentValues {
    var gravityTheme: GravityTheme {
        get { self[GravityThemeKey.self] }
        set { self[GravityThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects the Gravity theme into the environment. Apply on your app root.
    func gravityTheme(_ theme: GravityTheme = .current) -> some View {
        environment(\.gravityTheme, theme)
    }
}

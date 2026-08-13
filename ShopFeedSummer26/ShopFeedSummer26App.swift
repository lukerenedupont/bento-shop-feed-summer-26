import SwiftUI

@main
struct ShopFeedSummer26App: App {
    init() {
        GravityTheme.registerFonts()

        #if DEBUG
        PurlInjectionDiagnostics.install()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
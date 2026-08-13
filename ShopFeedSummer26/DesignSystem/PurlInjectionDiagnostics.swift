#if DEBUG
import Foundation
import os.log

private let purlInjectLog = OSLog(subsystem: "com.shopify.purl", category: "inject")

@MainActor
enum PurlInjectionDiagnostics {
    static func install() {
        PurlTuneRuntime.shared.install()

        NotificationCenter.default.addObserver(
            forName: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"),
            object: nil,
            queue: .main
        ) { _ in
            os_log("[PURL_INJECT] notification timestamp=%{public}f",
                   log: purlInjectLog, type: .info,
                   Date().timeIntervalSince1970)
        }
    }
}
#endif

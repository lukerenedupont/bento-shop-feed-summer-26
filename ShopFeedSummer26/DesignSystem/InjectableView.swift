import SwiftUI

#if DEBUG
/// View modifier that subscribes page-level views to Purl's debug-only Tune
/// value registry. When Purl drops a reload payload into the simulator app's
/// tmp directory, the registry publishes a change and SwiftUI recomputes the
/// subscribed page body.
struct InjectableView: ViewModifier {
    @ObservedObject private var runtime = PurlTuneRuntime.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.purlTuneRevision, runtime.revision)
    }
}
#endif

extension View {
    /// Enable Purl Tune live reload for this view. In Debug builds, this
    /// subscribes the view to Purl's filesystem-backed Tune runtime. In Release
    /// builds, it's a no-op.
    ///
    /// Usage: Apply to page-level views in their body root.
    ///
    /// ```swift
    /// var body: some View {
    ///     VStack {
    ///         // page content
    ///     }
    ///     .purlInjectable()
    /// }
    /// ```
    func purlInjectable() -> some View {
        #if DEBUG
        modifier(InjectableView())
        #else
        self
        #endif
    }
}

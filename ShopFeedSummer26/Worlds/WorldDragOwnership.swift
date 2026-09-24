import SwiftUI

/// A descendant temporarily owns manipulation; the surrounding page must not
/// scroll beneath the finger. Preference scope keeps this local to each World
/// or sheet rather than disabling scrolling globally.
struct WorldDragOwnership: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

struct WorldDragScrollLock: ViewModifier {
    @State private var manipulationOwnsTouch = false
    func body(content: Content) -> some View {
        content
            .scrollDisabled(manipulationOwnsTouch)
            .onPreferenceChange(WorldDragOwnership.self) { manipulationOwnsTouch = $0 }
    }
}

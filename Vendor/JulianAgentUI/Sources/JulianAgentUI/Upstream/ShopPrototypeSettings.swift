import SwiftUI
import Gravity
import UIKit

struct ShopNavigationStylePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedStyle: ShopBottomNavigationStyle
    let onSelect: (ShopBottomNavigationStyle) -> Void

    var body: some View {
        NavigationStack {
            Form {
                ShopPrototypeSettingsSections(selectedStyle: $selectedStyle, onSelectStyle: onSelect)
            }
            .navigationTitle("Bottom navigation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The same prototype controls and defaults in internal and development builds.
struct ShopPrototypeSettingsSections: View {
    @AppStorage(ShopHomeSearchLayout.storageKey) private var homeSearchLayout = ShopHomeSearchLayout.full
    @AppStorage(ShopConversationStarterGlass.enabledStorageKey) private var starterGlassEnabled = true
    @State private var appIcon = ShopPrototypeAppIcon.current
    @State private var isChangingAppIcon = false

    @Binding var selectedStyle: ShopBottomNavigationStyle
    let onSelectStyle: (ShopBottomNavigationStyle) -> Void
    var onReset: () -> Void = { }

    var body: some View {
        ShopNavigationStylePickerSection(selectedStyle: $selectedStyle, onSelect: onSelectStyle)
        ShopHomeSearchLayoutPickerSection(selection: $homeSearchLayout)
        Section {
            Toggle("Glass", isOn: $starterGlassEnabled)
                .accessibilityLabel("Conversation starter glass")
                .accessibilityIdentifier("prototype-conversation-starter-glass-toggle")
        } header: {
            Text("Conversation starters")
        } footer: {
            Text("Applies to inline starters and the cards above the composer. Turn off for solid backgrounds.")
        }
        ShopAppIconPickerSection(selection: $appIcon, isChangingIcon: $isChangingAppIcon)
        Section {
            Button("Reset to defaults") {
                // Internal builds default to Pistons; don't reset unrelated flags or account data.
                selectedStyle = .pistons
                homeSearchLayout = .full
                starterGlassEnabled = true
                appIcon = .defaultIcon
                onReset()
            }
            .disabled(isChangingAppIcon)
            .accessibilityIdentifier("prototype-reset-defaults")
        } footer: {
            Text("Restores Pistons, full search, starter glass, and the default app icon.")
        }
    }
}

struct ShopHomeSearchLayoutPickerSection: View {
    @Binding var selection: ShopHomeSearchLayout

    var body: some View {
        Section {
            Picker("Home search", selection: $selection) {
                ForEach(ShopHomeSearchLayout.allCases, id: \.self) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("home-search-layout-picker")
        } header: {
            Text("Home search")
        } footer: {
            Text("Choose how search appears on Home or in the tab bar.")
        }
    }
}

struct ShopNavigationStylePickerSection: View {
    @Binding var selectedStyle: ShopBottomNavigationStyle
    let onSelect: (ShopBottomNavigationStyle) -> Void

    var body: some View {
        Section {
            Picker("Layout", selection: $selectedStyle) {
                Text("Rodeo")
                    .tag(ShopBottomNavigationStyle.rodeo)
                    .accessibilityHint("Centered tabs with the composer on the leading side.")
                Text("Pistons")
                    .tag(ShopBottomNavigationStyle.pistons)
                    .accessibilityHint("Leading tabs with the composer beside the cart.")
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .accessibilityIdentifier("navigation-style-picker")
            .onChange(of: selectedStyle) { _, style in
                onSelect(style)
            }
        } footer: {
            Text("Choose how the tabs and composer are arranged.")
        }
    }
}


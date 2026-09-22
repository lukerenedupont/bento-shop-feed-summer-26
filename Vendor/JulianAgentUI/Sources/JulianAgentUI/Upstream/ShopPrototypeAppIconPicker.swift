import SwiftUI
import UIKit

enum ShopPrototypeAppIcon: String, CaseIterable, Identifiable {
    case shopicon
    case shopicon2
    case shopicon3
    case shopicon4
    case shopicon5
    case shopicon6
    case shopicon7
    case shopicon8
    case shopicon9
    case shopicon10
    case shopicon11
    case shopicon12
    case shopiconpainted
    case shopiconpainted2

    static let defaultIcon = Self.shopiconpainted2

    var id: String { rawValue }

    var title: String {
        self == Self.defaultIcon ? "\(rawValue) (Default)" : rawValue
    }

    var alternateIconName: String? {
        self == Self.defaultIcon ? nil : rawValue
    }

    @MainActor
    static var current: Self {
        guard let alternateIconName = UIApplication.shared.alternateIconName else {
            return defaultIcon
        }
        return Self(rawValue: alternateIconName) ?? defaultIcon
    }
}

struct ShopAppIconPickerSection: View {
    @Binding var selection: ShopPrototypeAppIcon
    @Binding var isChangingIcon: Bool
    @State private var showsError = false

    var body: some View {
        Section {
            Picker(
                "App icon",
                selection: $selection
            ) {
                ForEach(ShopPrototypeAppIcon.allCases) { icon in
                    Text(icon.title).tag(icon)
                }
            }
            .pickerStyle(.navigationLink)
            .disabled(!UIApplication.shared.supportsAlternateIcons || isChangingIcon)
            .accessibilityIdentifier("prototype-app-icon-picker")
        } header: {
            Text("App icon")
        } footer: {
            Text("Choose the icon shown on the Home Screen. iOS may ask you to confirm the change.")
        }
        .onChange(of: selection) { _, icon in
            select(icon)
        }
        .alert("Couldn't change app icon", isPresented: $showsError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your previous icon is still selected. Please try again.")
        }
    }

    private func select(_ icon: ShopPrototypeAppIcon) {
        guard icon != ShopPrototypeAppIcon.current else { return }
        guard UIApplication.shared.supportsAlternateIcons, !isChangingIcon else {
            selection = ShopPrototypeAppIcon.current
            return
        }
        isChangingIcon = true
        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            Task { @MainActor in
                isChangingIcon = false
                selection = ShopPrototypeAppIcon.current
                showsError = error != nil
            }
        }
    }
}

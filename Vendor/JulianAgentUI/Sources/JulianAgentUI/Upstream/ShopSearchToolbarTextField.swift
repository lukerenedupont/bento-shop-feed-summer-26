import Gravity
import SwiftUI
import UIKit

/// Keeps a single UIKit first responder while SwiftUI animates its toolbar frame.
struct ShopSearchToolbarTextField: UIViewRepresentable {
    @Binding var query: String
    @Binding var isActive: Bool
    let placeholder: String
    let foregroundColor: Color
    let placeholderColor: Color
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.enablesReturnKeyAutomatically = true
        field.adjustsFontForContentSizeCategory = true
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.accessibilityIdentifier = "search-toolbar-input"
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // Host-adapter boundary: an obscured search field must not reclaim focus
        // from the shell-owned composer when another navigation host mounts.
        field.isEnabled = context.environment.isEnabled
        field.font = GravityTextStyle.bodyLarge.scaledUIFont
        field.textColor = UIColor(foregroundColor)
        field.tintColor = UIColor(foregroundColor)
        field.defaultTextAttributes[.kern] = GravityTextStyle.bodyLarge.kerning
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: UIColor(placeholderColor),
            .kern: GravityTextStyle.bodyLarge.kerning,
        ])
        field.accessibilityLabel = placeholder
        if field.text != query { field.text = query }

        guard !context.coordinator.isUpdatingFocus else { return }
        context.coordinator.isUpdatingFocus = true
        defer { context.coordinator.isUpdatingFocus = false }

        if isActive, !field.isFirstResponder, field.window != nil {
            field.becomeFirstResponder()
        } else if !isActive, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return CGSize(width: max(0, width), height: GravitySpacing.space44)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    static func dismantleUIView(_ field: UITextField, coordinator: Coordinator) {
        field.delegate = nil
        field.removeTarget(coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.resignFirstResponder()
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: ShopSearchToolbarTextField
        var isUpdatingFocus = false

        init(parent: ShopSearchToolbarTextField) { self.parent = parent }

        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            guard textField.isEnabled else { return false }
            // A focus request from updateUIView already reflects SwiftUI's intent.
            // In particular, don't reverse a dismissal while UIKit is resigning.
            guard !isUpdatingFocus else { return parent.isActive }
            // Request toolbar expansion before UIKit starts editing and shows the keyboard.
            if !parent.isActive { parent.isActive = true }
            return true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.isActive { parent.isActive = false }
        }

        @objc func textChanged(_ field: UITextField) {
            let text = field.text ?? ""
            if parent.query != text { parent.query = text }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            return false
        }
    }
}

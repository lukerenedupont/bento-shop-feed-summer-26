import SwiftUI
import Gravity
import UIKit

/// A retained conversation can collapse the search field into a return-to-results control.
struct ShopSearchToolbarReturnContext {
    let title: String
    let isPresented: Bool
    let onReturn: () -> Void
}


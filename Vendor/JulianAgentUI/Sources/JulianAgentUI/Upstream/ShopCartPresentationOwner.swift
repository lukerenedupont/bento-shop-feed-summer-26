import SwiftUI
import Gravity
import UIKit

enum ShopCartPresentationOwner: Equatable {
    case shell
    case mini

    init(isMiniPresented: Bool) {
        self = isMiniPresented ? .mini : .shell
    }

    var animationSource: ShopAddToCartAnimationSource {
        switch self {
        case .shell:
            .standard
        case .mini:
            .mini
        }
    }
}


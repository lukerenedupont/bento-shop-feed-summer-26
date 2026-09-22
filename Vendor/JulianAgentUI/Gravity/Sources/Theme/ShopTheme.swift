import SwiftUI

public struct ShopTheme<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .tint(GravityColor.textBrand)
    }
}

#Preview("ShopTheme") {
    ShopTheme {
        ShopText("Themed content")
            .padding()
    }
}

import SwiftUI

struct ShopCollectionListHostedContent<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

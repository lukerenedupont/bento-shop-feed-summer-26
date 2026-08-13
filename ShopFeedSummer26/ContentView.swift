import SwiftUI

/// Entry point for the buyer-profile feed prototype.
///
/// The personalized assortment is bundled so the prototype opens directly
/// into the flick-and-stick feed without requiring Shop Server authentication.
struct ContentView: View {
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @State private var userProfile = UserProfileService.shared
    @State private var historyClient = ConversationHistoryClient.shared

    var body: some View {
        RootView()
            .task {
                if merchantService.merchants.isEmpty {
                    merchantService.loadFallbackData()
                    userProfile.applyFallbackProfile()
                }
                await historyClient.fetch()
            }
    }
}

#Preview {
    ContentView()
}

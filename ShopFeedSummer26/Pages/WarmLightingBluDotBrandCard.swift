import SwiftUI

/// Exact implementation of Figma node 2418:42438 for the warm-lighting page.
struct WarmLightingBluDotBrandCard: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("topicFollowedMerchantIDs") private var followedMerchantIDs = ""

    private let productAssets = (1...6).map { "bludot-product-\($0)" }

    private var isFollowing: Bool {
        followedMerchantIDs.split(separator: ",").contains("figma-blu-dot")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(hex: "#897D5C")

            Image("bludot-cover")
                .resizable()
                .scaledToFit()
                .frame(width: 364, alignment: .top)

            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#897D5C").opacity(0.20), location: 0),
                    .init(color: Color(hex: "#897D5C"), location: 0.28),
                    .init(color: Color(hex: "#897D5C"), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(.white)
                    Image("bludot-logo")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(hex: "#309DB9"))
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())

                Spacer()

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Text("4.8")
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("(320.6K)")
                    }
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white)

                    Button {
                        toggleFollow()
                    } label: {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(GravityFont.semiBold.fixedFont(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
                .frame(height: 60)
            }
            .frame(width: 340, height: 80, alignment: .top)
            .padding(.top, 10)
            .padding(.horizontal, 12)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(108), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(Array(productAssets.enumerated()), id: \.offset) { _, asset in
                    productTile(asset)
                }
            }
            .frame(width: 340)
            .padding(.top, 100)
            .padding(.horizontal, 12)

            Button {
                HapticFeedback.light.fire()
                if let url = URL(string: "https://www.bludot.com") { openURL(url) }
            } label: {
                HStack(spacing: 5) {
                    Text("Shop all")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(GravityFont.semiBold.fixedFont(size: 20))
                .foregroundStyle(.white)
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.leading, 12)
            .padding(.top, 346)
        }
        .frame(width: 364, height: 388)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        }
    }

    private func productTile(_ asset: String) -> some View {
        ZStack {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 108)
                .clipped()

            Text("$20.00")
                .font(GravityFont.medium.fixedFont(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: 20)
                .background(.black.opacity(0.38), in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)

            Image(systemName: "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(10)
        }
        .frame(width: 108, height: 108)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private func toggleFollow() {
        HapticFeedback.light.fire()
        var ids = Set(followedMerchantIDs.split(separator: ",").map(String.init))
        if isFollowing { ids.remove("figma-blu-dot") } else { ids.insert("figma-blu-dot") }
        followedMerchantIDs = ids.sorted().joined(separator: ",")
    }
}

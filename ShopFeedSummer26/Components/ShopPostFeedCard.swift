import SwiftUI

/// Full-height treatment for a real merchant-authored Shop Post.
struct ShopPostFeedCard: View {
    let post: ShopPost
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool
    var cornerRadius: CGFloat = GravityRadius.r28
    var bottomCornerRadius: CGFloat? = nil
    var borderOpacity: Double = 0.16
    var shadowOpacity: Double = 1

    private var resolvedBottomCornerRadius: CGFloat {
        bottomCornerRadius ?? cornerRadius
    }

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            bottomLeadingRadius: resolvedBottomCornerRadius,
            bottomTrailingRadius: resolvedBottomCornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            media
                .frame(width: width, height: height)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.04), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 12) {
                merchantLogo

                VStack(alignment: .leading, spacing: 5) {
                    Text(post.merchant.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    if let copy = primaryCopy {
                        Text(copy)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(width: width, height: height)
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.5)
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(0.12 * shadowOpacity),
            radius: 24,
            x: 0,
            y: 4
        )
        .contentShape(cardShape)
        .onTapGesture {
            guard let actionURL = post.actionURL else { return }
            UIApplication.shared.open(actionURL)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Post from \(post.merchant.name). \(primaryCopy ?? "")")
    }

    @ViewBuilder
    private var media: some View {
        switch post.media {
        case let .video(url, posterURL, _, _):
            ZStack {
                if let posterURL {
                    postImage(url: posterURL, contentMode: .fill)
                } else {
                    Color.black
                }
                if isActive {
                    LoopingVideoPlayer(url: url)
                        .transition(.opacity)
                }
            }
        case let .image(url, _, _):
            postImage(url: url, contentMode: .fill)
        }
    }

    @ViewBuilder
    private var merchantLogo: some View {
        if let logoURL = post.merchant.logoURL {
            postImage(url: logoURL, contentMode: .fit)
                .padding(7)
                .frame(width: 44, height: 44)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text(post.merchant.name.prefix(1))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var primaryCopy: String? {
        [post.title, post.caption]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func postImage(url: URL, contentMode: ContentMode) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .empty:
                Color.black.opacity(0.08)
            case .failure:
                Color.black.opacity(0.14)
            @unknown default:
                Color.black.opacity(0.08)
            }
        }
    }
}

import CoreGraphics
import UIKit

public enum ShopCollectionEndReachedThreshold: Equatable, Sendable {
    /// Absolute distance in points from the end of the scroll content.
    case absolute(CGFloat)
    /// Distance expressed in visible viewport lengths. This matches React Native's
    /// `onEndReachedThreshold` / FlashList's `onEndReachedThresholdRelative` contract.
    case relative(CGFloat)

    func distance(visibleLength: CGFloat) -> CGFloat {
        switch self {
        case let .absolute(distance):
            max(distance, 0)
        case let .relative(multiplier):
            max(multiplier, 0) * visibleLength
        }
    }
}

@MainActor
public struct ShopCollectionEndReachedController {
    public enum TriggerReason: Sendable {
        case threshold
    }

    public struct Trigger: Sendable {
        public let reason: TriggerReason
        public let distanceFromEnd: CGFloat
        public let thresholdDistance: CGFloat
        public let contentLength: CGFloat
        public let visibleLength: CGFloat
        public let offset: CGFloat
    }

    private enum Metrics {
        static let edgeEpsilon: CGFloat = 0.001
        static let contentLengthChangeEpsilon: CGFloat = 0.5
    }

    private struct ContentLengthTriggerKey: Hashable {
        let bucket: Int

        init(_ contentLength: CGFloat) {
            bucket = Int((contentLength / Metrics.contentLengthChangeEpsilon).rounded(.toNearestOrAwayFromZero))
        }
    }

    private enum State: Equatable {
        case armed
        case triggered(AnyHashable)
    }

    private var state: State = .armed

    public var hasTriggered: Bool {
        if case .triggered = state {
            return true
        }
        return false
    }

    public init() {}

    public mutating func rearm() {
        state = .armed
    }

    public mutating func rearm(_ token: AnyHashable) {
        guard case let .triggered(triggeredToken) = state,
              triggeredToken != token else {
            return
        }

        state = .armed
    }

    private func resolvedTriggerKey(
        contentLength: CGFloat,
        rearmKey: AnyHashable?
    ) -> AnyHashable {
        if let rearmKey {
            return rearmKey
        }

        let contentLengthKey = ContentLengthTriggerKey(contentLength)
        guard case let .triggered(triggeredKey) = state,
              let triggeredContentLengthKey = triggeredKey.base as? ContentLengthTriggerKey,
              triggeredContentLengthKey.bucket > contentLengthKey.bucket else {
            return AnyHashable(contentLengthKey)
        }

        return triggeredKey
    }

    /// Evaluates the current scroll position and returns a trigger the first time the end is
    /// reached, staying latched until something re-arms it.
    ///
    /// - Parameter rearmsWhenLeavingThreshold: When `true`, scrolling back out of the threshold
    ///   zone re-arms the controller, so scrolling away and returning triggers again even though
    ///   the content did not change. This is RecyclerListView's contract, which FlashList and
    ///   therefore the RN feed inherit: `_onEndReachedCalled` is reset in the `else` branch of its
    ///   threshold check. Callers that re-arm purely on content progress can leave this `false`,
    ///   but a caller whose next page may render nothing needs it — otherwise a zero-progress
    ///   append latches pagination off permanently.
    public mutating func evaluate(
        in scrollView: UIScrollView,
        hasEndReachedHandler: Bool,
        itemCount: Int,
        threshold: ShopCollectionEndReachedThreshold,
        contentLengthOverride: CGFloat? = nil,
        rearmKey: AnyHashable? = nil,
        rearmsWhenLeavingThreshold: Bool = false
    ) -> Trigger? {
        let visibleLength = scrollView.bounds.height
        let contentLength = contentLengthOverride ?? scrollView.contentSize.height
        let offset = scrollView.contentOffset.y

        guard itemCount > 0,
              contentLength > 0,
              visibleLength > 0 else {
            return nil
        }

        var distanceFromEnd = contentLength - visibleLength - offset
        if distanceFromEnd < Metrics.edgeEpsilon {
            distanceFromEnd = 0
        }

        let thresholdDistance = threshold.distance(visibleLength: visibleLength)
        let isWithinThreshold = distanceFromEnd <= thresholdDistance

        guard hasEndReachedHandler else {
            return nil
        }

        guard isWithinThreshold else {
            if rearmsWhenLeavingThreshold {
                rearm()
            }
            return nil
        }

        let triggerKey = resolvedTriggerKey(
            contentLength: contentLength,
            rearmKey: rearmKey
        )
        rearm(triggerKey)

        guard case .armed = state else {
            return nil
        }

        state = .triggered(triggerKey)

        return Trigger(
            reason: .threshold,
            distanceFromEnd: distanceFromEnd,
            thresholdDistance: thresholdDistance,
            contentLength: contentLength,
            visibleLength: visibleLength,
            offset: offset
        )
    }
}

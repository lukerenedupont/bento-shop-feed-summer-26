import Testing
import UIKit
@testable import Gravity

@MainActor
struct ShopCollectionEndReachedControllerTests {
    @Test
    func triggersOnceWhileParkedInsideTheThreshold() {
        var controller = ShopCollectionEndReachedController()
        let scrollView = makeScrollView(offset: atEnd)

        #expect(evaluate(&controller, scrollView) != nil)
        #expect(evaluate(&controller, scrollView) == nil)
    }

    @Test
    func rearmsAfterLeavingAndReenteringTheThreshold() {
        var controller = ShopCollectionEndReachedController()
        let scrollView = makeScrollView(offset: atEnd)

        #expect(evaluate(&controller, scrollView) != nil)

        scrollView.contentOffset.y = farFromEnd
        #expect(evaluate(&controller, scrollView) == nil)

        scrollView.contentOffset.y = atEnd
        #expect(evaluate(&controller, scrollView) != nil)
    }

    @Test
    func doesNotRearmOnLeavingWhenTheCallerOptsOut() {
        var controller = ShopCollectionEndReachedController()
        let scrollView = makeScrollView(offset: atEnd)

        #expect(evaluate(&controller, scrollView, rearmsWhenLeavingThreshold: false) != nil)

        scrollView.contentOffset.y = farFromEnd
        #expect(evaluate(&controller, scrollView, rearmsWhenLeavingThreshold: false) == nil)

        scrollView.contentOffset.y = atEnd
        #expect(evaluate(&controller, scrollView, rearmsWhenLeavingThreshold: false) == nil)
    }

    @Test
    func rearmSurvivesAnAppendThatRendersNothing() {
        var controller = ShopCollectionEndReachedController()
        let scrollView = makeScrollView(offset: atEnd)
        let unchangedRearmKey = AnyHashable(["section-1"])

        #expect(evaluate(&controller, scrollView, rearmKey: unchangedRearmKey) != nil)
        #expect(evaluate(&controller, scrollView, rearmKey: unchangedRearmKey) == nil)

        scrollView.contentOffset.y = farFromEnd
        #expect(evaluate(&controller, scrollView, rearmKey: unchangedRearmKey) == nil)

        scrollView.contentOffset.y = atEnd
        #expect(evaluate(&controller, scrollView, rearmKey: unchangedRearmKey) != nil)
    }

    @Test
    func leavingTheThresholdWithoutAHandlerDoesNotRearm() {
        var controller = ShopCollectionEndReachedController()
        let scrollView = makeScrollView(offset: atEnd)

        #expect(evaluate(&controller, scrollView) != nil)

        scrollView.contentOffset.y = farFromEnd
        #expect(evaluate(&controller, scrollView, hasEndReachedHandler: false) == nil)

        scrollView.contentOffset.y = atEnd
        #expect(evaluate(&controller, scrollView) == nil)
    }

    private let viewportHeight: CGFloat = 1000
    private let contentHeight: CGFloat = 10000
    /// Threshold is 2 viewports, so the trigger zone starts 2000pt from the end.
    private let atEnd: CGFloat = 8000
    private let farFromEnd: CGFloat = 5000

    private func makeScrollView(offset: CGFloat) -> UIScrollView {
        let scrollView = UIScrollView(frame: CGRect(x: 0, y: 0, width: 400, height: viewportHeight))
        scrollView.contentSize = CGSize(width: 400, height: contentHeight)
        scrollView.contentOffset = CGPoint(x: 0, y: offset)
        return scrollView
    }

    private func evaluate(
        _ controller: inout ShopCollectionEndReachedController,
        _ scrollView: UIScrollView,
        hasEndReachedHandler: Bool = true,
        rearmKey: AnyHashable? = nil,
        rearmsWhenLeavingThreshold: Bool = true
    ) -> ShopCollectionEndReachedController.Trigger? {
        controller.evaluate(
            in: scrollView,
            hasEndReachedHandler: hasEndReachedHandler,
            itemCount: 20,
            threshold: .relative(2),
            rearmKey: rearmKey,
            rearmsWhenLeavingThreshold: rearmsWhenLeavingThreshold
        )
    }
}

import CoreGraphics
import Foundation
import Testing
@testable import Gravity

struct ShopFlowLayoutMeasurementTests {
    @Test
    func childNarrowerThanTheRowKeepsItsIdealWidth() {
        #expect(shopFlowLayoutNeedsBoundedMeasurement(idealWidth: 120, maxWidth: 370) == false)
    }

    @Test
    func childWiderThanTheRowIsRemeasured() {
        #expect(shopFlowLayoutNeedsBoundedMeasurement(idealWidth: 800, maxWidth: 370))
    }

    @Test
    func childExactlyFillingTheRowIsRemeasured() {
        #expect(shopFlowLayoutNeedsBoundedMeasurement(idealWidth: 370, maxWidth: 370))
    }

    @Test
    func unboundedRowNeverRemeasures() {
        #expect(shopFlowLayoutNeedsBoundedMeasurement(idealWidth: 800, maxWidth: .infinity) == false)
    }

    @Test
    func zeroWidthRowNeverRemeasures() {
        #expect(shopFlowLayoutNeedsBoundedMeasurement(idealWidth: 800, maxWidth: 0) == false)
    }
}

import CoreGraphics
import XCTest
@testable import DisplayShiftCore

final class LayoutTests: XCTestCase {
    func testSideAndBottomUseQuartzCoordinates() throws {
        let external = display("External", x: 0, y: 0, primary: true)
        let side = display("Built-in", x: 1920, y: -160)
        let bottom = display("Built-in", x: 0, y: 1080)

        let plan = try Layout.placements(for: [external, bottom], on: [side, external])

        XCTAssertEqual(plan, [.init(id: bottom.id, x: 0, y: 1080),
                              .init(id: external.id, x: 0, y: 0)])
        XCTAssertFalse(Layout.matches([external, side], [external, bottom]))
    }

    func testNormalizesAnyPrimaryOriginAndPreservesArrangementOrderIndependence() throws {
        let primary = display("Primary", x: 1920, y: 1080, primary: true)
        let above = display("Above", x: 1920, y: 0)
        let left = display("Left", x: 0, y: 1080)

        let plan = try Layout.placements(for: [primary, above, left], on: [left, primary, above])
        XCTAssertEqual(plan, [.init(id: above.id, x: 0, y: -1080),
                              .init(id: left.id, x: -1920, y: 0),
                              .init(id: primary.id, x: 0, y: 0)])
        XCTAssertTrue(Layout.matches([primary, above, left], [left, primary, above]))
    }

    func testChangingPrimaryChangesExpectedArrangement() throws {
        let external = display("External", x: 0, y: 0, primary: true)
        let laptop = display("Built-in", x: 0, y: 1080)
        let promoted = display("Built-in", x: 0, y: 0, primary: true)
        let moved = display("External", x: 0, y: -1080)

        XCTAssertFalse(Layout.matches([external, laptop], [promoted, moved]))
        XCTAssertEqual(try Layout.placements(for: [promoted, moved], on: [external, laptop]),
                       [.init(id: external.id, x: 0, y: -1080), .init(id: laptop.id, x: 0, y: 0)])
    }

    func testMissingDisplayReportsName() {
        let laptop = display("Built-in", x: 0, y: 0, primary: true)
        let external = display("Studio Display", x: 1920, y: 0)

        XCTAssertThrowsError(try Layout.placements(for: [laptop, external], on: [laptop])) { error in
            guard case LayoutError.missing(let names) = error else {
                return XCTFail("Expected missing display, received \(error)")
            }
            XCTAssertEqual(names, [external.name])
        }
        XCTAssertFalse(Layout.matches([laptop, external], [laptop]))
    }

    func testUnexpectedActiveDisplayPreventsRestoration() {
        let laptop = display("Built-in", x: 0, y: 0, primary: true)
        let extra = display("Extra", x: 1920, y: 0)

        XCTAssertThrowsError(try Layout.placements(for: [laptop], on: [laptop, extra])) { error in
            guard case LayoutError.extra(let names) = error else {
                return XCTFail("Expected extra display, received \(error)")
            }
            XCTAssertEqual(names, [extra.name])
        }
    }

    func testDuplicateIdentitiesAreRejected() {
        let primary = display("Same ID", x: 0, y: 0, primary: true)
        let other = display("Same ID", x: 1920, y: 0)

        XCTAssertThrowsError(try Layout.placements(for: [primary, other], on: [primary, other])) { error in
            guard case LayoutError.ambiguous = error else { return XCTFail("Expected ambiguous display IDs") }
        }
    }

    func testInvalidPrimaryOrOutOfRangeCoordinatesAreRejected() {
        let primary = display("Primary", x: 0, y: 0, primary: true)
        let other = display("Other", x: CGFloat(Int32.max) + 1, y: 0)

        for invalid in [[other], [primary, other]] {
            XCTAssertThrowsError(try Layout.placements(for: invalid, on: invalid)) { error in
                guard case LayoutError.invalid = error else { return XCTFail("Expected invalid arrangement") }
            }
        }
    }

    private func display(_ name: String, x: CGFloat, y: CGFloat, primary: Bool = false) -> Display {
        Display(id: name, name: name, bounds: CGRect(x: x, y: y, width: 1920, height: 1080),
                primary: primary, builtIn: name == "Built-in")
    }
}

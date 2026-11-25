import CoreGraphics
import XCTest
@testable import DisplayShiftCore

final class LayoutDraftTests: XCTestCase {
    func testDragFromRightToBelowSnapsAndAlignsCenters() throws {
        let external = display("External", x: 0, y: 0, width: 200, height: 100, primary: true)
        let laptop = display("Laptop", x: 200, y: 0, width: 100, height: 70)
        let current = [external, laptop]
        var draft = LayoutDraft(displays: current)

        XCTAssertTrue(draft.move(laptop.id, to: CGPoint(x: 53, y: 105),
                                 snapDistance: 20, alignmentDistance: 8))
        XCTAssertEqual(draft.displays[1].bounds.origin, CGPoint(x: 50, y: 100))
        XCTAssertEqual(draft.displays[1].bounds.size, laptop.bounds.size)
        XCTAssertEqual(draft.displays[0], external)
        XCTAssertNoThrow(try draft.validate(on: current))
    }

    func testDraggingPrimaryKeepsItsIdentityAndNormalizesCoordinates() throws {
        let primary = display("Primary", x: 0, y: 0, primary: true)
        let other = display("Other", x: 100, y: 0)
        let current = [primary, other]
        var draft = LayoutDraft(displays: current)

        XCTAssertTrue(draft.move(primary.id, to: CGPoint(x: 101, y: -101),
                                 snapDistance: 20, alignmentDistance: 8))
        XCTAssertEqual(try Layout.placements(for: draft.displays, on: current),
                       [.init(id: other.id, x: 0, y: 100), .init(id: primary.id, x: 0, y: 0)])
    }

    func testInvalidDropLeavesDraftUnchanged() {
        let current = [display("First", x: 0, y: 0, primary: true),
                       display("Bridge", x: 100, y: 0),
                       display("Last", x: 200, y: 0)]
        var draft = LayoutDraft(displays: current)

        XCTAssertFalse(draft.move("Bridge", to: CGPoint(x: 0, y: 100),
                                  snapDistance: 20, alignmentDistance: 8))
        XCTAssertFalse(draft.move("Last", to: CGPoint(x: 0, y: 0),
                                  snapDistance: 20, alignmentDistance: 8))
        XCTAssertEqual(draft.displays, current)
    }

    func testValidationRejectsChangedSizeAndMissingDisplays() {
        let first = display("First", x: 0, y: 0, primary: true)
        let second = display("Second", x: 100, y: 0)
        let draft = LayoutDraft(displays: [first, second])
        let resized = display("Second", x: 100, y: 0, width: 120)

        XCTAssertThrowsError(try draft.validate(on: [first, resized])) { error in
            guard case LayoutError.displaySizeChanged = error else { return XCTFail("Expected size change") }
        }
        XCTAssertThrowsError(try draft.validate(on: [first])) { error in
            guard case LayoutError.missing([second.name]) = error else { return XCTFail("Expected missing display") }
        }
    }

    func testValidationRejectsCornerOnlyContact() {
        let first = display("First", x: 0, y: 0, primary: true)
        let corner = display("Corner", x: 100, y: 100)
        let current = [first, corner]
        XCTAssertThrowsError(try LayoutDraft(displays: current).validate(on: current)) { error in
            guard case LayoutError.disconnectedDraft = error else { return XCTFail("Expected disconnected layout") }
        }
    }

    private func display(_ name: String, x: CGFloat, y: CGFloat, width: CGFloat = 100,
                         height: CGFloat = 100, primary: Bool = false) -> Display {
        Display(id: name, name: name, bounds: CGRect(x: x, y: y, width: width, height: height),
                primary: primary, builtIn: false)
    }
}

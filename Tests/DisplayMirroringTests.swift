import XCTest
@testable import DisplayShiftCore

final class DisplayMirroringTests: XCTestCase {
    func testMirrorUsesCurrentMainForEveryOtherDisplay() throws {
        let extended = DisplayMirroring(main: 2, sources: [1: 0, 2: 0, 3: 0])
        let mirrored = try extended.setting(.mirrorMain)

        XCTAssertEqual(mirrored.mode, .mirrorMain)
        XCTAssertEqual(extended.changes(to: mirrored), [
            .init(display: 1, source: 2), .init(display: 3, source: 2)
        ])
    }

    func testExtendClearsOnlyMirrorFollowers() throws {
        let mirrored = DisplayMirroring(main: 1, sources: [1: 0, 2: 1, 3: 0])
        let extended = try mirrored.setting(.extended)

        XCTAssertNil(mirrored.mode)
        XCTAssertEqual(extended.mode, .extended)
        XCTAssertEqual(mirrored.changes(to: extended), [.init(display: 2, source: 0)])
    }

    func testSingleDisplayCannotChangeMirroring() {
        let single = DisplayMirroring(main: 1, sources: [1: 0])
        XCTAssertFalse(single.canChange)
        XCTAssertThrowsError(try single.setting(.mirrorMain))
    }

    func testDraftPrimarySelectionKeepsRelativePositions() throws {
        let first = Display(id: "first", name: "First", bounds: CGRect(x: 0, y: 0, width: 100, height: 80),
                            primary: true, builtIn: false)
        let second = Display(id: "second", name: "Second", bounds: CGRect(x: 100, y: 0, width: 100, height: 80),
                             primary: false, builtIn: false)
        var draft = LayoutDraft(displays: [first, second])
        draft.setPrimary(second.id)
        draft.setPrimary("unknown")

        XCTAssertEqual(draft.displays.filter(\.primary).map(\.id), [second.id])
        XCTAssertEqual(draft.displays.map(\.bounds), [first.bounds, second.bounds])
        XCTAssertEqual(try Layout.placements(for: draft.displays, on: [first, second]), [
            .init(id: first.id, x: -100, y: 0), .init(id: second.id, x: 0, y: 0)
        ])
    }
}

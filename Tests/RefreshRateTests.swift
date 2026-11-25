import CoreGraphics
import XCTest
@testable import DisplayShiftCore

final class RefreshRateTests: XCTestCase {
    func testOnlyExplicitRefreshRatesAffectPresetMatching() {
        let actual = display(rate: 60)
        XCTAssertTrue(Layout.matchesRequest([display(rate: nil)], [actual]))
        XCTAssertTrue(Layout.matchesRequest([display(rate: 60)], [actual]))
        XCTAssertFalse(Layout.matchesRequest([display(rate: 144)], [actual]))
    }

    func testDraftDoesNotCaptureRefreshRateWithoutAnExplicitSelection() {
        var draft = LayoutDraft(displays: [display(rate: 60)])
        XCTAssertNil(draft.displays.first?.refreshRate)
        draft.setRefreshRate(144, for: "screen")
        XCTAssertEqual(draft.displays.first?.refreshRate, 144)
        draft.setRefreshRate(nil, for: "screen")
        XCTAssertNil(draft.displays.first?.refreshRate)
    }

    func testOlderPresetsWithNoRateOrRotationStillDecode() throws {
        let fixture = Data("""
        {"id":"screen","name":"External","bounds":[[0,0],[1920,1080]],"primary":true,"builtIn":false}
        """.utf8)
        let decoded = try JSONDecoder().decode(Display.self, from: fixture)
        XCTAssertNil(decoded.refreshRate)
        XCTAssertNil(decoded.rotation)
        XCTAssertEqual(decoded.bounds.size, CGSize(width: 1920, height: 1080))
    }

    private func display(rate: Double?) -> Display {
        Display(id: "screen", name: "External", bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                primary: true, builtIn: false, refreshRate: rate)
    }
}

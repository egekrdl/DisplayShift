import XCTest
@testable import DisplayShiftCore

final class PresetStoreTests: XCTestCase {
    func testRoundTripPreservesIdentityOrderAndDisplayMetadata() throws {
        let suite = "DisplayShift-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PresetStore(defaults: defaults)
        let external = Display(id: "external", name: "External", bounds: CGRect(x: -2560, y: 100, width: 2560, height: 1440),
                               primary: false, builtIn: false)
        let builtIn = Display(id: "built-in", name: "Built-in", bounds: CGRect(x: 0, y: 0, width: 1512, height: 982),
                              primary: true, builtIn: true)
        let presets = [Preset(name: "Side Setup", displays: [builtIn, external]),
                       Preset(name: "Solo", displays: [builtIn])]

        XCTAssertTrue(try store.load().isEmpty)
        try store.save(presets)
        let reloaded = try PresetStore(defaults: defaults).load()

        XCTAssertEqual(reloaded.map(\.id), presets.map(\.id))
        XCTAssertEqual(reloaded.map(\.name), presets.map(\.name))
        XCTAssertEqual(reloaded.map(\.displays), presets.map(\.displays))
    }

    func testInvalidPayloadIsReportedAndPreserved() throws {
        let suite = "DisplayShift-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PresetStore(defaults: defaults)
        let payload = Data("invalid".utf8)
        defaults.set(payload, forKey: store.key)

        XCTAssertThrowsError(try store.load())
        XCTAssertEqual(defaults.data(forKey: store.key), payload)
    }

    func testShortcutSettingsRoundTripAndDefaultPair() throws {
        let first = UUID()
        let second = UUID()
        let side = Shortcut.suggested(for: "Side Setup")
        XCTAssertEqual(side.label, "⌃⌥1")
        XCTAssertEqual(Shortcut.suggested(for: "Bottom Setup").label, "⌃⌥2")
        XCTAssertEqual(Shortcut.toggleDefault.label, "⌃⌥Space")
        XCTAssertFalse(ShortcutSettings(first: first, second: first).pair.count == 2)

        let settings = ShortcutSettings(presets: [first: side], first: first, second: second)
        let restored = try JSONDecoder().decode(ShortcutSettings.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored.pair, [first, second])
        XCTAssertEqual(restored.presets[first], side)
        XCTAssertEqual(restored.toggle, .toggleDefault)
    }
}

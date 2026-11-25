import AppKit
import CoreGraphics

@MainActor
protocol DisplayManaging {
    func current() throws -> [Display]
    func apply(_ displays: [Display]) async throws
}

@MainActor
final class QuartzDisplays: DisplayManaging {
    private struct Screen {
        let handle: CGDirectDisplayID
        let display: Display
    }

    func current() throws -> [Display] {
        try snapshot().map(\.display)
    }

    func apply(_ displays: [Display]) async throws {
        let before = try snapshot()
        let original = before.map(\.display)
        let plan = try Layout.placements(for: displays, on: original)
        if Layout.matches(displays, original) { return }
        try commit(plan, to: before)
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard let after = try? snapshot() else { throw LayoutError.verification(false) }
        if Layout.matches(displays, after.map(\.display)) { return }
        var restored = Layout.matches(original, after.map(\.display))
        if !restored, let rollback = try? Layout.placements(for: original, on: after.map(\.display)) {
            do {
                try commit(rollback, to: after)
                try? await Task.sleep(nanoseconds: 350_000_000)
                restored = (try? current()).map { Layout.matches(original, $0) } ?? false
            } catch {
                restored = false
            }
        }
        throw LayoutError.verification(restored)
    }

    private func snapshot() throws -> [Screen] {
        var count: UInt32 = 0
        try check(CGGetActiveDisplayList(0, nil, &count), "Detecting displays")
        guard count > 0 else { throw LayoutError.unavailable }
        var handles = [CGDirectDisplayID](repeating: 0, count: Int(count))
        try check(CGGetActiveDisplayList(count, &handles, &count), "Reading displays")
        let screens = NSScreen.screens
        var result: [Screen] = []
        for handle in handles.prefix(Int(count)) {
            guard CGDisplayIsInMirrorSet(handle) == 0 else { throw LayoutError.mirrored }
            let builtIn = CGDisplayIsBuiltin(handle) != 0
            let serial = CGDisplaySerialNumber(handle)
            let vendor = CGDisplayVendorNumber(handle)
            let model = CGDisplayModelNumber(handle)
            let id: String
            if serial != 0 && serial != UInt32.max {
                id = "serial-\(vendor)-\(model)-\(serial)"
            } else if let uuid = CGDisplayCreateUUIDFromDisplayID(handle)?.takeRetainedValue() {
                id = "uuid-\(CFUUIDCreateString(nil, uuid) as String)"
            } else {
                id = "session-\(vendor)-\(model)-\(handle)"
            }
            let screen = screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == handle
            }
            let name = screen?.localizedName ?? (builtIn ? "Built-in Display" : "External Display")
            let display = Display(id: id, name: name, bounds: CGDisplayBounds(handle),
                                  primary: CGDisplayIsMain(handle) != 0, builtIn: builtIn)
            result.append(Screen(handle: handle, display: display))
        }
        guard !result.isEmpty else { throw LayoutError.unavailable }
        return result
    }

    private func commit(_ plan: [Layout.Placement], to screens: [Screen]) throws {
        let handles = Dictionary(uniqueKeysWithValues: screens.map { ($0.display.id, $0.handle) })
        var config: CGDisplayConfigRef?
        try check(CGBeginDisplayConfiguration(&config), "Starting display configuration")
        do {
            for placement in plan {
                guard let handle = handles[placement.id] else { throw LayoutError.invalid }
                try check(CGConfigureDisplayOrigin(config, handle, placement.x, placement.y), "Arranging displays")
            }
        } catch {
            CGCancelDisplayConfiguration(config)
            throw error
        }
        try check(CGCompleteDisplayConfiguration(config, .forSession), "Applying display configuration")
    }

    private func check(_ error: CGError, _ operation: String) throws {
        guard error == .success else { throw LayoutError.system(operation, error.rawValue) }
    }
}

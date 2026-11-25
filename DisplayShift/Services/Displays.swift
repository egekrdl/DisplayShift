import AppKit
import CoreGraphics

@MainActor
protocol DisplayManaging {
    func current() throws -> [Display]
    func connected() throws -> [Display]
    func refreshRates(for id: String) throws -> [Double]
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

    func connected() throws -> [Display] {
        try readDisplays(online: true).map(\.display)
    }

    func refreshRates(for id: String) throws -> [Double] {
        guard let screen = try snapshot().first(where: { $0.display.id == id }),
              let current = CGDisplayCopyDisplayMode(screen.handle) else { return [] }
        return Array(Set(compatibleModes(for: screen, matching: current).map(\.refreshRate))).sorted()
    }

    func apply(_ displays: [Display]) async throws {
        let before = try snapshot()
        let original = before.map(\.display)
        let plan = try Layout.placements(for: displays, on: original)
        if Layout.matchesRequest(displays, original) { return }
        let screens = Dictionary(uniqueKeysWithValues: before.map { ($0.display.id, $0) })
        var requestedModes: [String: CGDisplayMode] = [:]
        var originalModes: [String: CGDisplayMode] = [:]
        for display in displays {
            guard let rate = display.refreshRate, let screen = screens[display.id],
                  rate != screen.display.refreshRate else { continue }
            guard let current = CGDisplayCopyDisplayMode(screen.handle),
                  let mode = compatibleModes(for: screen, matching: current).first(where: { $0.refreshRate == rate }) else {
                throw LayoutError.unsupportedRefreshRate(display.name)
            }
            requestedModes[display.id] = mode
            originalModes[display.id] = current
        }

        try commit(plan, modes: requestedModes, to: before)
        try? await Task.sleep(nanoseconds: 350_000_000)
        guard let after = try? snapshot() else { throw LayoutError.verification(false) }
        if Layout.matchesRequest(displays, after.map(\.display)) { return }

        let rollbackTarget = original.map { display in
            var display = display
            if originalModes[display.id] == nil { display.refreshRate = nil }
            return display
        }
        var restored = Layout.matchesRequest(rollbackTarget, after.map(\.display))
        if !restored, let rollback = try? Layout.placements(for: rollbackTarget, on: after.map(\.display)),
           after.allSatisfy({ screen in
               originalModes[screen.display.id] == nil || screens[screen.display.id]?.handle == screen.handle
           }) {
            do {
                try commit(rollback, modes: originalModes, to: after)
                try? await Task.sleep(nanoseconds: 350_000_000)
                restored = (try? current()).map { Layout.matchesRequest(rollbackTarget, $0) } ?? false
            } catch {
                restored = false
            }
        }
        throw LayoutError.verification(restored)
    }

    private func compatibleModes(for screen: Screen, matching current: CGDisplayMode) -> [CGDisplayMode] {
        let modes = CGDisplayCopyAllDisplayModes(screen.handle, nil) as? [CGDisplayMode] ?? []
        return modes.filter { mode in
            mode.isUsableForDesktopGUI() && mode.refreshRate.isFinite && mode.refreshRate > 0 &&
                mode.width == current.width && mode.height == current.height &&
                mode.pixelWidth == current.pixelWidth && mode.pixelHeight == current.pixelHeight
        }.sorted { lhs, rhs in
            lhs.ioFlags == current.ioFlags && rhs.ioFlags != current.ioFlags
        }
    }

    private func snapshot() throws -> [Screen] {
        let screens = try readDisplays(online: false)
        guard !screens.isEmpty else { throw LayoutError.unavailable }
        guard screens.allSatisfy({ CGDisplayIsInMirrorSet($0.handle) == 0 }) else {
            throw LayoutError.mirrored
        }
        return screens
    }

    private func readDisplays(online: Bool) throws -> [Screen] {
        let list = online ? CGGetOnlineDisplayList : CGGetActiveDisplayList
        var count: UInt32 = 0
        try check(list(0, nil, &count), "Detecting displays")
        guard count > 0 else { return [] }
        var handles = [CGDirectDisplayID](repeating: 0, count: Int(count))
        try check(list(count, &handles, &count), "Reading displays")
        let screens = NSScreen.screens
        let result = handles.prefix(Int(count)).map { handle in
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
                                  primary: CGDisplayIsMain(handle) != 0, builtIn: builtIn,
                                  refreshRate: CGDisplayCopyDisplayMode(handle)?.refreshRate,
                                  rotation: CGDisplayRotation(handle))
            return Screen(handle: handle, display: display)
        }
        let countByID = Dictionary(grouping: result, by: { $0.display.id })
        return result.map { screen in
            guard (countByID[screen.display.id]?.count ?? 0) > 1,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(screen.handle)?.takeRetainedValue() else {
                return screen
            }
            var display = screen.display
            display.id = "uuid-\(CFUUIDCreateString(nil, uuid) as String)"
            return Screen(handle: screen.handle, display: display)
        }
    }

    private func commit(_ plan: [Layout.Placement], modes: [String: CGDisplayMode], to screens: [Screen]) throws {
        let handles = Dictionary(uniqueKeysWithValues: screens.map { ($0.display.id, $0.handle) })
        var config: CGDisplayConfigRef?
        try check(CGBeginDisplayConfiguration(&config), "Starting display configuration")
        do {
            for (id, mode) in modes {
                guard let handle = handles[id] else { throw LayoutError.invalid }
                try check(CGConfigureDisplayWithDisplayMode(config, handle, mode, nil), "Setting refresh rate")
            }
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

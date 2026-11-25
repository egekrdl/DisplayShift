import Foundation
import CoreGraphics

struct Display: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var bounds: CGRect
    var primary: Bool
    var builtIn: Bool
    var refreshRate: Double? = nil
    var rotation: Double? = nil
}

struct Preset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var displays: [Display]
}

enum LayoutError: LocalizedError {
    case unavailable, mirrored, ambiguous, missing([String]), extra([String])
    case displaySizeChanged, disconnectedDraft, unsupportedRefreshRate(String)
    case invalid, system(String, Int32), verification(Bool), emptyName, toggle

    var errorDescription: String? {
        switch self {
        case .unavailable: return "No usable displays were found."
        case .mirrored: return "Turn off display mirroring before saving or applying an arrangement."
        case .ambiguous: return "macOS reported duplicate display identifiers. The displays cannot be matched safely."
        case .missing(let names): return "Connect the required displays: \(names.joined(separator: ", "))."
        case .extra(let names): return "This preset does not include these active displays: \(names.joined(separator: ", "))."
        case .unsupportedRefreshRate(let name): return "The selected refresh rate is unavailable for \(name) at its current resolution and scaling."
        case .displaySizeChanged: return "A display changed size. Reset the editor to load the current displays."
        case .disconnectedDraft: return "Each display must touch another display along an edge, without overlap."
        case .invalid: return "This arrangement contains invalid display coordinates or a missing primary display."
        case .system(let operation, let code): return "\(operation) failed (Core Graphics error \(code))."
        case .verification(let restored):
            return restored
                ? "macOS did not apply the requested arrangement. The previous layout was verified."
                : "macOS did not apply the requested arrangement. Check the current layout in System Settings."
        case .emptyName: return "Enter a preset name."
        case .toggle: return "Choose two different presets in Shortcuts settings."
        }
    }
}

enum Layout {
    struct Placement: Hashable {
        let id: String
        let x: Int32
        let y: Int32
    }

    static func placements(for saved: [Display], on current: [Display]) throws -> [Placement] {
        let savedIDs = Set(saved.map(\.id))
        let currentIDs = Set(current.map(\.id))
        guard savedIDs.count == saved.count, currentIDs.count == current.count else {
            throw LayoutError.ambiguous
        }
        let missing = saved.filter { !currentIDs.contains($0.id) }
        guard missing.isEmpty else { throw LayoutError.missing(missing.map(\.name)) }
        let extra = current.filter { !savedIDs.contains($0.id) }
        guard extra.isEmpty else { throw LayoutError.extra(extra.map(\.name)) }
        guard saved.allSatisfy({ display in
            let bounds = display.bounds
            return bounds.minX.isFinite && bounds.minY.isFinite &&
                bounds.width.isFinite && bounds.height.isFinite &&
                bounds.width > 0 && bounds.height > 0
        }) else { throw LayoutError.invalid }
        let primary = saved.filter(\.primary)
        guard primary.count == 1, let anchor = primary.first else { throw LayoutError.invalid }
        return try (saved.filter { !$0.primary } + primary).map { display in
            guard let x = Int32(exactly: display.bounds.minX - anchor.bounds.minX),
                  let y = Int32(exactly: display.bounds.minY - anchor.bounds.minY),
                  display.primary || x != 0 || y != 0 else { throw LayoutError.invalid }
            return Placement(id: display.id, x: x, y: y)
        }
    }

    static func matchesRequest(_ requested: [Display], _ current: [Display]) -> Bool {
        guard matches(requested, current) else { return false }
        let rates = Dictionary(uniqueKeysWithValues: current.compactMap { display in
            display.refreshRate.map { (display.id, $0) }
        })
        return requested.allSatisfy { display in
            guard let rate = display.refreshRate else { return true }
            return rates[display.id] == rate
        }
    }

    static func matches(_ saved: [Display], _ current: [Display]) -> Bool {
        guard let expected = try? placements(for: saved, on: current),
              let actual = try? placements(for: current, on: saved) else { return false }
        return Set(expected) == Set(actual)
    }
}

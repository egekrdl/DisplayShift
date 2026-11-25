import CoreGraphics

enum DisplayMode: String {
    case extended = "Extend Displays"
    case mirrorMain = "Mirror Main Display"
}

struct DisplayMirroring: Equatable {
    struct Change: Equatable {
        let display: CGDirectDisplayID
        let source: CGDirectDisplayID
    }

    let main: CGDirectDisplayID
    let sources: [CGDirectDisplayID: CGDirectDisplayID]

    var canChange: Bool { sources.count > 1 && sources[main] != nil }

    var mode: DisplayMode? {
        if sources.values.allSatisfy({ $0 == kCGNullDirectDisplay }) { return .extended }
        guard canChange, sources[main] == kCGNullDirectDisplay,
              sources.allSatisfy({ $0.key == main || $0.value == main }) else { return nil }
        return .mirrorMain
    }

    func setting(_ mode: DisplayMode) throws -> DisplayMirroring {
        guard canChange else { throw LayoutError.mirroringNeedsTwoDisplays }
        let desired = Dictionary(uniqueKeysWithValues: sources.keys.map { display in
            (display, mode == .mirrorMain && display != main ? main : kCGNullDirectDisplay)
        })
        return DisplayMirroring(main: main, sources: desired)
    }

    func changes(to desired: DisplayMirroring) -> [Change] {
        desired.sources.keys.sorted().compactMap { display in
            guard let source = desired.sources[display], sources[display] != source else { return nil }
            return Change(display: display, source: source)
        }
    }
}

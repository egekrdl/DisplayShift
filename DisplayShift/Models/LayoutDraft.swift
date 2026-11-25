import CoreGraphics

struct LayoutDraft {
    private(set) var displays: [Display]

    init(displays: [Display]) {
        self.displays = displays.map { display in
            var display = display
            display.refreshRate = nil
            return display
        }
    }

    mutating func setPrimary(_ id: String) {
        guard displays.contains(where: { $0.id == id }) else { return }
        for index in displays.indices {
            displays[index].primary = displays[index].id == id
        }
    }

    mutating func setRefreshRate(_ rate: Double?, for id: String) {
        guard let index = displays.firstIndex(where: { $0.id == id }) else { return }
        displays[index].refreshRate = rate
    }

    mutating func move(_ id: String, to origin: CGPoint, snapDistance: CGFloat, alignmentDistance: CGFloat) -> Bool {
        guard let index = displays.firstIndex(where: { $0.id == id }) else { return false }
        let size = displays[index].bounds.size
        let neighbors = displays.filter { $0.id != id }
        var closest: (bounds: CGRect, distance: CGFloat)?
        var closestAligned: (bounds: CGRect, distance: CGFloat)?

        for neighbor in neighbors.map(\.bounds) {
            let vertical = aligned(origin.y, length: size.height, to: neighbor.minY...neighbor.maxY,
                                   distance: alignmentDistance)
            let horizontal = aligned(origin.x, length: size.width, to: neighbor.minX...neighbor.maxX,
                                     distance: alignmentDistance)
            for (value, aligned) in vertical {
                consider(CGPoint(x: neighbor.minX - size.width, y: value), aligned: aligned)
                consider(CGPoint(x: neighbor.maxX, y: value), aligned: aligned)
            }
            for (value, aligned) in horizontal {
                consider(CGPoint(x: value, y: neighbor.minY - size.height), aligned: aligned)
                consider(CGPoint(x: value, y: neighbor.maxY), aligned: aligned)
            }
        }

        guard let best = closestAligned ?? closest else { return false }
        if let closest, closest.distance + alignmentDistance < best.distance {
            displays[index].bounds = closest.bounds
        } else {
            displays[index].bounds = best.bounds
        }
        return true

        func consider(_ candidate: CGPoint, aligned: Bool) {
            let distance = hypot(candidate.x - origin.x, candidate.y - origin.y)
            let best = aligned ? closestAligned : closest
            guard distance <= snapDistance, distance < (best?.distance ?? .infinity) else { return }
            let bounds = CGRect(origin: candidate, size: size)
            var edited = displays
            edited[index].bounds = bounds
            guard Self.isConnected(edited) else { return }
            if aligned { closestAligned = (bounds, distance) }
            else { closest = (bounds, distance) }
        }
    }

    func validate(on current: [Display]) throws {
        _ = try Layout.placements(for: displays, on: current)
        let sizes = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0.bounds.size) })
        guard displays.allSatisfy({ sizes[$0.id] == $0.bounds.size }) else {
            throw LayoutError.displaySizeChanged
        }
        guard Self.isConnected(displays) else { throw LayoutError.disconnectedDraft }
    }

    private func aligned(_ value: CGFloat, length: CGFloat, to edge: ClosedRange<CGFloat>,
                         distance: CGFloat) -> [(CGFloat, Bool)] {
        let lower = edge.lowerBound
        let upper = edge.upperBound
        let aligned = [lower, (lower + upper - length) / 2, upper - length]
            .map { $0.rounded() }
            .filter { abs($0 - value) <= distance }
            .sorted { abs($0 - value) < abs($1 - value) }
        // Leave at least one point of shared edge, even near a corner.
        let clamped = min(max(value.rounded(), lower - length + 1), upper - 1)
        return aligned.map { ($0, true) } + [(clamped, false)]
    }

    private static func isConnected(_ displays: [Display]) -> Bool {
        guard !displays.isEmpty else { return false }
        let rects = displays.map(\.bounds)
        var neighbors = Array(repeating: [Int](), count: rects.count)
        for (index, first) in rects.enumerated() {
            for other in rects.indices.dropFirst(index + 1) {
                let second = rects[other]
                let horizontal = min(first.maxX, second.maxX) - max(first.minX, second.minX)
                let vertical = min(first.maxY, second.maxY) - max(first.minY, second.minY)
                if horizontal > 0 && vertical > 0 { return false }
                if (horizontal == 0 && vertical > 0) || (vertical == 0 && horizontal > 0) {
                    neighbors[index].append(other)
                    neighbors[other].append(index)
                }
            }
        }

        var visited: Set<Int> = [0]
        var pending = [0]
        while let index = pending.popLast() {
            for neighbor in neighbors[index] where visited.insert(neighbor).inserted {
                pending.append(neighbor)
            }
        }
        return visited.count == rects.count
    }
}

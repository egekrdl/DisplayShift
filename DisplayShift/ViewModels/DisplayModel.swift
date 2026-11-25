import SwiftUI

@MainActor
final class DisplayModel: ObservableObject {
    @Published private(set) var presets: [Preset] = []
    @Published private(set) var current: [Display] = []
    @Published private(set) var busy = false
    @Published var error: String?

    let manager: any DisplayManaging
    private let store: PresetStore
    private var storageAvailable = true

    init(manager: any DisplayManaging, store: PresetStore = PresetStore()) {
        self.manager = manager
        self.store = store
        do { presets = try store.load() } catch {
            storageAvailable = false
            self.error = "Saved presets could not be read. The stored data was preserved."
        }
        refresh()
    }

    func refresh() {
        current = (try? manager.current()) ?? []
    }

    func isActive(_ preset: Preset) -> Bool {
        Layout.matches(preset.displays, current)
    }

    func capture(_ name: String) -> Bool {
        perform {
            let name = try validName(name)
            let displays = try manager.current()
            _ = try Layout.placements(for: displays, on: displays)
            try persist(presets + [Preset(name: name, displays: displays)])
        }
    }

    func apply(_ preset: Preset) {
        guard !busy else { return }
        busy = true
        Task {
            defer { refresh(); busy = false }
            do { try await manager.apply(preset.displays) } catch { self.error = error.localizedDescription }
        }
    }

    func rename(_ id: UUID, to name: String) {
        edit(id) { $0.name = try validName(name) }
    }

    func update(_ id: UUID) {
        edit(id) {
            let displays = try manager.current()
            _ = try Layout.placements(for: displays, on: displays)
            $0.displays = displays
        }
    }

    func remove(_ id: UUID) {
        perform { try persist(presets.filter { $0.id != id }) }
    }

    func move(_ id: UUID, by offset: Int) {
        guard let index = presets.firstIndex(where: { $0.id == id }),
              presets.indices.contains(index + offset) else { return }
        var reordered = presets
        reordered.swapAt(index, index + offset)
        perform { try persist(reordered) }
    }

    private func edit(_ id: UUID, change: (inout Preset) throws -> Void) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        perform {
            var edited = presets
            try change(&edited[index])
            try persist(edited)
        }
    }

    private func persist(_ edited: [Preset]) throws {
        guard storageAvailable else { throw CocoaError(.fileReadCorruptFile) }
        try store.save(edited)
        presets = edited
    }

    private func validName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LayoutError.emptyName }
        return trimmed
    }

    @discardableResult
    private func perform(_ operation: () throws -> Void) -> Bool {
        guard !busy else { return false }
        do {
            try operation()
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class DisplayModel: ObservableObject {
    @Published private(set) var presets: [Preset] = []
    @Published private(set) var current: [Display] = []
    @Published private(set) var connected: [Display] = []
    @Published private(set) var busy = false
    @Published var error: String?
    @Published private(set) var shortcuts = ShortcutSettings()
    @Published private(set) var unavailableShortcuts: Set<ShortcutAction> = []
    @Published private(set) var loginStatus = SMAppService.Status.notRegistered
    @Published var showActiveName: Bool {
        didSet { store.defaults.set(showActiveName, forKey: "showActiveName") }
    }

    private let hotKeys = GlobalShortcuts()
    private var observations: Set<AnyCancellable> = []

    let manager: any DisplayManaging
    private let store: PresetStore
    private var storageAvailable = true

    init(manager: any DisplayManaging, store: PresetStore = PresetStore()) {
        self.manager = manager
        self.store = store
        showActiveName = store.defaults.bool(forKey: "showActiveName")
        do { presets = try store.load() } catch {
            storageAvailable = false
            self.error = "Saved presets could not be read. The stored data was preserved."
        }
        if let data = store.defaults.data(forKey: "shortcuts.v1") {
            do { shortcuts = try JSONDecoder().decode(ShortcutSettings.self, from: data) }
            catch { self.error = "Shortcut preferences could not be read." }
        }
        hotKeys.onPress = { [weak self] action in self?.handle(action) }
        for preset in presets {
            registerAtLaunch(shortcuts.presets[preset.id], for: .preset(preset.id))
        }
        let ids = Set(presets.map(\.id))
        shortcuts.presets = shortcuts.presets.filter { ids.contains($0.key) }
        if let first = shortcuts.first, !ids.contains(first) { shortcuts.first = nil }
        if let second = shortcuts.second, !ids.contains(second) { shortcuts.second = nil }
        if canToggle { registerAtLaunch(shortcuts.toggle, for: .toggle) }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshLoginStatus() }
            .store(in: &observations)
        refresh()
        refreshLoginStatus()
    }

    func refresh() {
        current = (try? manager.current()) ?? []
        connected = (try? manager.connected()) ?? current
    }

    func isActive(_ preset: Preset) -> Bool {
        Layout.matches(preset.displays, current)
    }

    var activePreset: Preset? { presets.first(where: isActive) }

    var canToggle: Bool {
        shortcuts.pair.count == 2 && shortcuts.pair.allSatisfy { id in presets.contains { $0.id == id } }
    }

    func toggle() {
        guard canToggle,
              let first = presets.first(where: { $0.id == shortcuts.first }),
              let second = presets.first(where: { $0.id == shortcuts.second }) else {
            error = LayoutError.toggle.localizedDescription
            return
        }
        refresh()
        apply(isActive(first) ? second : first)
    }

    func setShortcut(_ shortcut: Shortcut?, for action: ShortcutAction) {
        perform {
            var edited = shortcuts
            switch action {
            case .preset(let id): edited.presets[id] = shortcut
            case .toggle: edited.toggle = shortcut
            }
            try validate(edited)
            if action != .toggle || canToggle { try hotKeys.set(shortcut, for: action) }
            try saveShortcuts(edited)
            unavailableShortcuts.remove(action)
        }
    }

    func selectTogglePreset(_ id: UUID?, first: Bool) {
        perform {
            var edited = shortcuts
            if first { edited.first = id } else { edited.second = id }
            let active = edited.pair.count == 2
            try hotKeys.set(active ? edited.toggle : nil, for: .toggle)
            try saveShortcuts(edited)
            unavailableShortcuts.remove(.toggle)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        defer { refreshLoginStatus() }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Launch at Login: \(error.localizedDescription)"
        }
    }

    private func refreshLoginStatus() {
        loginStatus = SMAppService.mainApp.status
    }

    private func registerAtLaunch(_ shortcut: Shortcut?, for action: ShortcutAction) {
        do { try hotKeys.set(shortcut, for: action) } catch {
            unavailableShortcuts.insert(action)
            if self.error == nil { self.error = error.localizedDescription }
        }
    }

    private func handle(_ action: ShortcutAction) {
        switch action {
        case .preset(let id):
            if let preset = presets.first(where: { $0.id == id }) { apply(preset) }
        case .toggle: toggle()
        }
    }

    private func validate(_ settings: ShortcutSettings) throws {
        var seen: Set<Shortcut> = []
        for shortcut in Array(settings.presets.values) + [settings.toggle].compactMap({ $0 }) {
            guard shortcut.valid else { throw ShortcutError.invalid }
            guard seen.insert(shortcut).inserted else { throw ShortcutError.duplicate(shortcut.label) }
        }
    }

    private func saveShortcuts(_ edited: ShortcutSettings) throws {
        store.defaults.set(try JSONEncoder().encode(edited), forKey: "shortcuts.v1")
        shortcuts = edited
    }

    func capture(_ name: String) -> Bool {
        perform {
            let name = try validName(name)
            let displays = try manager.current()
            _ = try Layout.placements(for: displays, on: displays)
            try persist(presets + [Preset(name: name, displays: displays)])
        }
    }

    func openLayoutDraft() -> LayoutDraft? {
        var draft: LayoutDraft?
        perform {
            let displays = try manager.current()
            _ = try Layout.placements(for: displays, on: displays)
            draft = LayoutDraft(displays: displays)
        }
        return draft
    }

    func saveDraft(_ draft: LayoutDraft, name: String) -> Bool {
        perform {
            let name = try validName(name)
            try draft.validate(on: manager.current())
            try persist(presets + [Preset(name: name, displays: draft.displays)])
        }
    }

    func applyDraft(_ draft: LayoutDraft) {
        applyLayout(draft.displays) { try draft.validate(on: self.manager.current()) }
    }

    func apply(_ preset: Preset) {
        applyLayout(preset.displays)
    }

    private func applyLayout(_ displays: [Display], validate: () throws -> Void = {}) {
        guard perform(validate) else { return }
        busy = true
        Task {
            defer { refresh(); busy = false }
            do { try await manager.apply(displays) } catch { self.error = error.localizedDescription }
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
        perform {
            try persist(presets.filter { $0.id != id })
            try hotKeys.set(nil, for: .preset(id))
            unavailableShortcuts.remove(.preset(id))
            var edited = shortcuts
            edited.presets.removeValue(forKey: id)
            if edited.first == id { edited.first = nil }
            if edited.second == id { edited.second = nil }
            if edited.pair.isEmpty {
                try hotKeys.set(nil, for: .toggle)
                unavailableShortcuts.remove(.toggle)
            }
            try saveShortcuts(edited)
        }
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

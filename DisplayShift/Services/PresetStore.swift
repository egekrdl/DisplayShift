import Foundation

struct PresetStore {
    var defaults: UserDefaults = .standard
    var key = "presets.v1"

    func load() throws -> [Preset] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([Preset].self, from: data)
    }

    func save(_ presets: [Preset]) throws {
        defaults.set(try JSONEncoder().encode(presets), forKey: key)
    }
}

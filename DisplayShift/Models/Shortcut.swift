import Carbon

struct Shortcut: Codable, Hashable {
    struct Key: Identifiable {
        let id: UInt32
        let label: String

        init(_ code: Int, _ label: String) {
            id = UInt32(code)
            self.label = label
        }
    }

    static let keys = [
        Key(kVK_ANSI_A, "A"), Key(kVK_ANSI_B, "B"), Key(kVK_ANSI_C, "C"),
        Key(kVK_ANSI_D, "D"), Key(kVK_ANSI_E, "E"), Key(kVK_ANSI_F, "F"),
        Key(kVK_ANSI_G, "G"), Key(kVK_ANSI_H, "H"), Key(kVK_ANSI_I, "I"),
        Key(kVK_ANSI_J, "J"), Key(kVK_ANSI_K, "K"), Key(kVK_ANSI_L, "L"),
        Key(kVK_ANSI_M, "M"), Key(kVK_ANSI_N, "N"), Key(kVK_ANSI_O, "O"),
        Key(kVK_ANSI_P, "P"), Key(kVK_ANSI_Q, "Q"), Key(kVK_ANSI_R, "R"),
        Key(kVK_ANSI_S, "S"), Key(kVK_ANSI_T, "T"), Key(kVK_ANSI_U, "U"),
        Key(kVK_ANSI_V, "V"), Key(kVK_ANSI_W, "W"), Key(kVK_ANSI_X, "X"),
        Key(kVK_ANSI_Y, "Y"), Key(kVK_ANSI_Z, "Z"),
        Key(kVK_ANSI_0, "0"), Key(kVK_ANSI_1, "1"), Key(kVK_ANSI_2, "2"),
        Key(kVK_ANSI_3, "3"), Key(kVK_ANSI_4, "4"), Key(kVK_ANSI_5, "5"),
        Key(kVK_ANSI_6, "6"), Key(kVK_ANSI_7, "7"), Key(kVK_ANSI_8, "8"), Key(kVK_ANSI_9, "9"),
        Key(kVK_Space, "Space"), Key(kVK_LeftArrow, "←"), Key(kVK_RightArrow, "→"),
        Key(kVK_UpArrow, "↑"), Key(kVK_DownArrow, "↓"),
        Key(kVK_F1, "F1"), Key(kVK_F2, "F2"), Key(kVK_F3, "F3"), Key(kVK_F4, "F4"),
        Key(kVK_F5, "F5"), Key(kVK_F6, "F6"), Key(kVK_F7, "F7"), Key(kVK_F8, "F8"),
        Key(kVK_F9, "F9"), Key(kVK_F10, "F10"), Key(kVK_F11, "F11"), Key(kVK_F12, "F12")
    ]

    var key = UInt32(kVK_Space)
    var control = true
    var option = true
    var shift = false
    var command = false

    static let toggleDefault = Shortcut()

    static func suggested(for name: String) -> Shortcut {
        switch name.lowercased() {
        case "side setup": return Shortcut(key: UInt32(kVK_ANSI_1))
        case "bottom setup": return Shortcut(key: UInt32(kVK_ANSI_2))
        default: return Shortcut()
        }
    }

    var modifiers: UInt32 {
        (control ? UInt32(controlKey) : 0) |
        (option ? UInt32(optionKey) : 0) |
        (shift ? UInt32(shiftKey) : 0) |
        (command ? UInt32(cmdKey) : 0)
    }

    var label: String {
        (control ? "⌃" : "") + (option ? "⌥" : "") +
        (shift ? "⇧" : "") + (command ? "⌘" : "") +
        (Self.keys.first { $0.id == key }?.label ?? "Key \(key)")
    }

    var valid: Bool {
        (control || option || command) && Self.keys.contains { $0.id == key }
    }
}

struct ShortcutSettings: Codable {
    var presets: [UUID: Shortcut] = [:]
    var toggle: Shortcut? = .toggleDefault
    var first: UUID?
    var second: UUID?

    var pair: [UUID] {
        guard let first, let second, first != second else { return [] }
        return [first, second]
    }
}

import Carbon
import Foundation

enum ShortcutAction: Hashable {
    case preset(UUID)
    case toggle
}

enum ShortcutError: LocalizedError {
    case invalid, duplicate(String), registration(String, OSStatus), handler(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalid: return "Choose a key and at least one of Control, Option, or Command."
        case .duplicate(let label): return "\(label) is already assigned in DisplayShift."
        case .registration(let label, let status):
            return "\(label) could not be registered. It may be reserved or in use (macOS error \(status))."
        case .handler(let status): return "Global shortcuts are unavailable (macOS error \(status))."
        }
    }
}

@MainActor
final class GlobalShortcuts {
    private struct Registration {
        let shortcut: Shortcut
        let id: UInt32
        let reference: EventHotKeyRef
    }

    private static let signature: OSType = 0x44534846
    private var registrations: [ShortcutAction: Registration] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1
    var onPress: ((ShortcutAction) -> Void)?

    func set(_ shortcut: Shortcut?, for action: ShortcutAction) throws {
        if registrations[action]?.shortcut == shortcut { return }
        guard let shortcut else {
            remove(action)
            return
        }
        guard shortcut.valid else { throw ShortcutError.invalid }
        guard !registrations.values.contains(where: { $0.shortcut == shortcut }) else {
            throw ShortcutError.duplicate(shortcut.label)
        }
        try installHandler()
        let id = nextID
        nextID &+= 1
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.key, shortcut.modifiers,
                                         EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &reference)
        guard status == noErr, let reference else { throw ShortcutError.registration(shortcut.label, status) }
        remove(action)
        registrations[action] = Registration(shortcut: shortcut, id: id, reference: reference)
    }

    private func remove(_ action: ShortcutAction) {
        if let previous = registrations.removeValue(forKey: action) {
            UnregisterEventHotKey(previous.reference)
        }
    }

    private func installHandler() throws {
        guard handler == nil else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyReleased))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, info in
            guard let event, let info else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr, hotKey.signature == 0x44534846 else {
                return OSStatus(eventNotHandledErr)
            }
            let service = Unmanaged<GlobalShortcuts>.fromOpaque(info).takeUnretainedValue()
            let id = hotKey.id
            Task { @MainActor in
                if let action = service.registrations.first(where: { $0.value.id == id })?.key {
                    service.onPress?(action)
                }
            }
            return noErr
        }, 1, &eventType, context, &handler)
        guard status == noErr else { throw ShortcutError.handler(status) }
    }

    deinit {
        for registration in registrations.values { UnregisterEventHotKey(registration.reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

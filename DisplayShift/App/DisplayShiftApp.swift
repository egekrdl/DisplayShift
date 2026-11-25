import AppKit
import SwiftUI

@main
struct DisplayShiftApp: App {
    @StateObject private var model = DisplayModel(manager: QuartzDisplays())
    private let settings = SettingsWindow.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(model: model, openSettings: { settings.show(model) },
                      openUpdates: { settings.show(model, tab: .updates) })
        } label: {
            let icon = model.error == nil ? "display.2" : "exclamationmark.circle"
            if model.showActiveName, let active = model.activePreset {
                Label(String(active.name.prefix(24)), systemImage: icon)
            } else {
                Image(systemName: icon).accessibilityLabel("DisplayShift")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class SettingsWindow: ObservableObject {
    enum Tab { case general, presets, shortcuts, updates, about }
    @Published var tab = Tab.general
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(_ model: DisplayModel, tab: Tab? = nil) {
        if let tab { self.tab = tab }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "DisplayShift Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsPanel(model: model, navigation: self))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

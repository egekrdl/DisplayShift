import AppKit
import SwiftUI

@main
struct DisplayShiftApp: App {
    @StateObject private var model = DisplayModel(manager: QuartzDisplays())
    private let settings = SettingsWindow.shared

    var body: some Scene {
        MenuBarExtra("DisplayShift", systemImage: "display.2") {
            MenuPanel(model: model) { settings.show(model) }
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(_ model: DisplayModel) {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "DisplayShift Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsPanel(model: model))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

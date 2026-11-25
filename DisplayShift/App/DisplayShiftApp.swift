import SwiftUI

@main
struct DisplayShiftApp: App {
    @StateObject private var model = DisplayModel(manager: QuartzDisplays())

    var body: some Scene {
        MenuBarExtra("DisplayShift", systemImage: "display.2") {
            MenuPanel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuPanel: View {
    @ObservedObject var model: DisplayModel
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DisplayShift").font(.headline)
            ForEach(model.presets) { preset in
                Button(preset.name) { model.apply(preset) }.disabled(model.busy)
            }
            TextField("Preset name", text: $name)
            Button("Save Current Layout") { model.capture(name); name = "" }.disabled(model.busy)
            Button("Quit DisplayShift") { NSApp.terminate(nil) }
        }
        .padding()
        .frame(width: 300)
        .onAppear { model.refresh() }
        .alert("DisplayShift", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button("OK") { model.error = nil }
        } message: {
            Text(model.error ?? "")
        }
    }
}

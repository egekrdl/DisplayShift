import SwiftUI

struct SettingsPanel: View {
    @ObservedObject var model: DisplayModel
    @ObservedObject var navigation: SettingsWindow
    @State private var selection: UUID?
    @State private var editedName = ""
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $navigation.tab) {
                general.tabItem { Label("General", systemImage: "gearshape") }.tag(SettingsWindow.Tab.general)
                presets.tabItem { Label("Presets", systemImage: "display.2") }.tag(SettingsWindow.Tab.presets)
                ShortcutsPanel(model: model).tabItem { Label("Shortcuts", systemImage: "keyboard") }.tag(SettingsWindow.Tab.shortcuts)
                UpdatesPanel(updates: .shared).tabItem { Label("Updates", systemImage: "arrow.down.circle") }
                    .tag(SettingsWindow.Tab.updates)
                about.tabItem { Label("About", systemImage: "info.circle") }.tag(SettingsWindow.Tab.about)
            }
            if let error = model.error {
                StatusMessage(message: error) { model.error = nil }
            }
        }
        .padding(16)
        .frame(width: 560, height: 440)
    }

    private var general: some View {
        Form {
            Section("Application") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { model.loginStatus == .enabled || model.loginStatus == .requiresApproval },
                    set: { model.setLaunchAtLogin($0) }
                ))
                if model.loginStatus == .requiresApproval {
                    Text("Allow DisplayShift in System Settings → General → Login Items.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Toggle("Show preset names only", isOn: $model.hidePresetPreviews)
                Toggle("Show active preset name in the menu bar", isOn: $model.showActiveName)
            }
            Section("Connected Displays") {
                if model.connected.isEmpty {
                    Text("No connected displays reported by macOS.").foregroundStyle(.secondary)
                }
                ForEach(Array(model.connected.enumerated()), id: \.offset) { _, display in
                    LabeledContent(display.name) {
                        let kind = display.builtIn ? "Built-in" : "External"
                        let primary = display.primary ? " · Primary" : ""
                        Text("\(Int(display.bounds.width)) × \(Int(display.bounds.height)) · \(kind)\(primary)")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(selection: $selection) {
                ForEach(model.presets) { preset in
                    HStack {
                        if !model.hidePresetPreviews { LayoutPreview(displays: preset.displays, active: model.isActive(preset)) }
                        Text(preset.name).lineLimit(1)
                        Spacer()
                        if !model.hidePresetPreviews { Text("\(preset.displays.count) displays").foregroundStyle(.secondary) }
                    }
                    .tag(preset.id)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 120)
            if let selection, let index = model.presets.firstIndex(where: { $0.id == selection }) {
                HStack {
                    TextField("Preset name", text: $editedName)
                        .onSubmit { model.rename(selection, to: editedName) }
                    Button("Rename") { model.rename(selection, to: editedName) }
                }
                HStack {
                    Button("Update from Current Layout") { model.update(selection) }
                    Spacer()
                    Button { model.move(selection, by: -1) } label: { Image(systemName: "arrow.up") }
                        .disabled(index == 0).help("Move up").accessibilityLabel("Move up")
                    Button { model.move(selection, by: 1) } label: { Image(systemName: "arrow.down") }
                        .disabled(index == model.presets.count - 1).help("Move down").accessibilityLabel("Move down")
                    Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                        .help("Delete preset").accessibilityLabel("Delete preset")
                }
            } else {
                Text("Select a preset to edit it. Save new presets from the menu bar.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .disabled(model.busy)
        .onChange(of: selection) { id in
            editedName = model.presets.first { $0.id == id }?.name ?? ""
        }
        .confirmationDialog("Delete this preset?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Preset", role: .destructive) {
                if let selection { model.remove(selection); self.selection = nil }
            }
        }
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image(systemName: "display.2").font(.system(size: 45, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text("DisplayShift").font(.title.weight(.semibold))
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3.0")")
                .foregroundStyle(.secondary)
            Text("Save and switch between Mac display arrangements.")
            Text("Presets are stored on this Mac. DisplayShift works offline.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

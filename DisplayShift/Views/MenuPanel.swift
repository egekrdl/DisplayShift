import SwiftUI

struct MenuPanel: View {
    @ObservedObject var model: DisplayModel
    var openSettings: () -> Void
    var openUpdates: () -> Void
    @State private var name = ""
    @State private var naming = false
    @State private var draft: LayoutDraft?
    @FocusState private var nameFocused: Bool

    var body: some View {
        Group {
            if let draft {
                LayoutEditor(model: model, draft: draft) { self.draft = nil }
            } else {
                menu
            }
        }
        .onAppear { model.refresh() }
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "display.2").foregroundStyle(Color.accentColor)
                Text("DisplayShift").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            if model.presets.isEmpty {
                Text("Edit your display layout or save the current arrangement.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    VStack(spacing: 5) {
                        ForEach(model.presets) { preset in
                            presetRow(preset)
                        }
                    }
                }
                .frame(height: min(Double(model.presets.count), 5) * (model.hidePresetPreviews ? 37 : 56))
            }
            if let error = model.error {
                StatusMessage(message: error) { model.error = nil }
            }
            Divider()
            if naming {
                HStack {
                    TextField("Preset name", text: $name)
                        .focused($nameFocused)
                        .onSubmit(save)
                    Button("Save", action: save)
                        .disabled(model.busy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button { naming = false } label: {
                        Image(systemName: "xmark").accessibilityLabel("Cancel")
                    }
                }
            } else {
                action("Save Current Layout", icon: "plus.rectangle") {
                    naming = true
                    nameFocused = true
                }
                .disabled(model.busy)
            }
            action("Edit Layout…", icon: "rectangle.2.swap") {
                draft = model.openLayoutDraft()
            }
            .disabled(model.busy)
            Menu {
                displayModeAction(.extended)
                displayModeAction(.mirrorMain)
            } label: {
                Label("Display Mode", systemImage: "display.2")
            }
            .disabled(model.busy || model.mirroring?.canChange != true)
            .help("Extend the desktop or mirror the main display")
            action("Toggle Layout", icon: "arrow.left.arrow.right") { model.toggle() }
                .disabled(model.busy || !model.canToggle)
                .help(model.canToggle ? "Switch between the selected layouts" : "Choose two presets in Shortcuts settings")
            action("Check for Updates…", icon: "arrow.down.circle") {
                PrivateUpdates.shared.check()
                openUpdates()

            }
            action("Settings…", icon: "gearshape", run: openSettings)
            action("Quit DisplayShift", icon: "power") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 326)
    }

    private func save() {
        if model.capture(name) {
            name = ""
            naming = false
        }
    }

    private func presetRow(_ preset: Preset) -> some View {
        let active = model.isActive(preset)
        return Button { model.apply(preset) } label: {
            HStack(spacing: 9) {
                if !model.hidePresetPreviews { LayoutPreview(displays: preset.displays, active: active) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name).fontWeight(.medium).lineLimit(1)
                    if active && !model.hidePresetPreviews { Text("Active").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 5)
                if !model.hidePresetPreviews, let shortcut = model.shortcuts.presets[preset.id] {
                    Text(shortcut.label)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .help(model.unavailableShortcuts.contains(.preset(preset.id)) ? "Shortcut unavailable" : shortcut.label)
                }
                if active && !model.hidePresetPreviews {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: model.hidePresetPreviews ? 32 : 51)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.accentColor.opacity(0.10) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
        .help("Apply \(preset.name)")
        .disabled(model.busy)
    }

    private func displayModeAction(_ mode: DisplayMode) -> some View {
        Button {
            model.setDisplayMode(mode)
        } label: {
            if model.mirroring?.mode == mode {
                Label(mode.rawValue, systemImage: "checkmark")
            } else {
                Text(mode.rawValue)
            }
        }
        .disabled(model.mirroring?.mode == mode)
    }

    private func action(_ title: String, icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct StatusMessage: View {
    let message: String
    var dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
            Text(message).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark").accessibilityLabel("Dismiss message")
            }
            .buttonStyle(.borderless)
        }
        .font(.callout)
        .padding(9)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

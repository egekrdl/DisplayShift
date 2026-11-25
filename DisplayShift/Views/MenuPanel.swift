import SwiftUI

struct MenuPanel: View {
    @ObservedObject var model: DisplayModel
    var openSettings: () -> Void
    @State private var name = ""
    @State private var naming = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "display.2").foregroundStyle(Color.accentColor)
                Text("DisplayShift").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            if model.presets.isEmpty {
                Text("Arrange your displays in System Settings, then save the layout here.")
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
                .frame(height: min(Double(model.presets.count), 5) * 56)
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
            action("Settings…", icon: "gearshape", run: openSettings)
            action("Quit DisplayShift", icon: "power") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 326)
        .onAppear { model.refresh() }
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
                LayoutPreview(displays: preset.displays, active: active)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name).fontWeight(.medium).lineLimit(1)
                    if active { Text("Active").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 5)
                if active {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 51)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.accentColor.opacity(0.10) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Apply \(preset.name)")
        .disabled(model.busy)
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

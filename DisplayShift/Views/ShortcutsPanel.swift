import SwiftUI

struct ShortcutsPanel: View {
    @ObservedObject var model: DisplayModel
    @State private var action = ShortcutAction.toggle
    @State private var draft = Shortcut.toggleDefault

    var body: some View {
        Form {
            Section("Global Shortcuts") {
                Picker("Action", selection: $action) {
                    Text("Toggle Layout").tag(ShortcutAction.toggle)
                    ForEach(model.presets) { preset in
                        Text(preset.name).tag(ShortcutAction.preset(preset.id))
                    }
                }
                HStack {
                    Toggle("Control", isOn: $draft.control)
                    Toggle("Option", isOn: $draft.option)
                    Toggle("Shift", isOn: $draft.shift)
                    Toggle("Command", isOn: $draft.command)
                }
                Picker("Key", selection: $draft.key) {
                    ForEach(Shortcut.keys) { key in Text(key.label).tag(key.id) }
                }
                LabeledContent("Assigned") {
                    if let assigned {
                        Text(model.unavailableShortcuts.contains(action) ? "\(assigned.label) (Unavailable)" : assigned.label)
                    } else {
                        Text("None").foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Button("Assign Shortcut") { model.setShortcut(draft, for: action) }
                        .disabled(!draft.valid)
                    Button("Clear") { model.setShortcut(nil, for: action) }
                        .disabled(assigned == nil)
                }
            }

            Section("Toggle Pair") {
                pairPicker("First preset", first: true)
                pairPicker("Second preset", first: false)
                Text("When neither layout is active, Toggle Layout applies the first preset.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(model.busy)
        .onAppear(perform: loadDraft)
        .onChange(of: action) { _ in loadDraft() }
        .onChange(of: model.presets.map(\.id)) { ids in
            if case .preset(let id) = action, !ids.contains(id) { action = .toggle }
        }
    }

    private var assigned: Shortcut? {
        switch action {
        case .toggle: return model.shortcuts.toggle
        case .preset(let id): return model.shortcuts.presets[id]
        }
    }

    private func loadDraft() {
        if case .preset(let id) = action, let preset = model.presets.first(where: { $0.id == id }) {
            draft = assigned ?? .suggested(for: preset.name)
        } else {
            draft = assigned ?? .toggleDefault
        }
    }

    private func pairPicker(_ title: String, first: Bool) -> some View {
        let other = first ? model.shortcuts.second : model.shortcuts.first
        return Picker(title, selection: Binding(
            get: { first ? model.shortcuts.first : model.shortcuts.second },
            set: { model.selectTogglePreset($0, first: first) }
        )) {
            Text("None").tag(UUID?.none)
            ForEach(model.presets.filter { $0.id != other }) { preset in
                Text(preset.name).tag(Optional(preset.id))
            }
        }
    }
}

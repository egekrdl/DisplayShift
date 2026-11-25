import SwiftUI

struct LayoutEditor: View {
    @ObservedObject var model: DisplayModel
    let close: () -> Void

    @State private var draft: LayoutDraft
    @State private var name = ""
    @State private var feedback: String?
    @State private var selectedID: String
    @State private var rates: [Double] = []
    @GestureState private var drag: Drag?

    private struct Drag {
        let id: String
        let translation: CGSize
    }

    init(model: DisplayModel, draft: LayoutDraft, close: @escaping () -> Void) {
        self.model = model
        self.close = close
        _draft = State(initialValue: draft)
        _selectedID = State(initialValue: draft.displays.first?.id ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back to DisplayShift")
                Text("Edit Layout").font(.headline)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            Text(draft.displays.count > 1
                 ? "Drag a display next to another to snap their edges together."
                 : "Connect another display, then select Reset to arrange it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                let transform = Workspace(displays: draft.displays, size: geometry.size)
                let snapped = drag.flatMap { proposal(for: $0, in: transform) }
                ZStack(alignment: .topLeading) {
                    ForEach(draft.displays) { display in
                        let moving = drag?.id == display.id
                        let preview = snapped?.displays.first { $0.id == display.id } ?? display
                        let rect = transform.rect(for: preview.bounds)
                        let offset = moving && snapped == nil ? (drag?.translation ?? .zero) : .zero

                        tile(display, moving: moving, valid: snapped != nil, size: rect.size)
                            .position(x: rect.midX + offset.width, y: rect.midY + offset.height)
                            .onTapGesture { selectedID = display.id }
                            .gesture(gesture(for: display.id, in: transform))
                            .zIndex(moving ? 1 : 0)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .coordinateSpace(name: "layoutWorkspace")
            }
            .frame(height: 214)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(model.busy)

            displayControls
                .disabled(model.busy || drag != nil)

            if let error = model.error {
                StatusMessage(message: error) { model.error = nil }
            } else if let feedback {
                Text(feedback).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Button("Reset") {
                    if let current = model.openLayoutDraft() {
                        draft = current
                        if !current.displays.contains(where: { $0.id == selectedID }) {
                            selectedID = current.displays.first?.id ?? ""
                        }
                        reloadRates()
                        feedback = nil
                    }
                }
                .help("Reload the current display arrangement")
                Spacer()
                Button("Apply") {
                    feedback = nil
                    model.applyDraft(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(Layout.matchesRequest(draft.displays, model.current))
            }
            .disabled(model.busy || drag != nil)

            Divider()
            HStack {
                TextField("Preset name", text: $name).onSubmit(save)
                Button("Save as Preset", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .disabled(model.busy || drag != nil)
        }
        .padding(14)
        .frame(width: 402)
        .onAppear(perform: reloadRates)
        .onChange(of: selectedID) { _ in reloadRates() }
        .onChange(of: model.current) { _ in reloadRates() }
    }

    private var displayControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Display", selection: $selectedID) {
                ForEach(draft.displays) { display in
                    Text(display.name).tag(display.id)
                }
            }
            if let display = draft.displays.first(where: { $0.id == selectedID }) {
                Picker("Refresh Rate", selection: Binding(
                    get: { display.refreshRate },
                    set: { draft.setRefreshRate($0, for: selectedID) }
                )) {
                    Text("Keep Current").tag(Double?.none)
                    ForEach(rates, id: \.self) { rate in
                        Text("\(rate.formatted(.number.precision(.fractionLength(0...3)))) Hz").tag(Optional(rate))
                    }
                    if let rate = display.refreshRate, !rates.contains(rate) {
                        Text("\(rate.formatted()) Hz (Unavailable)").tag(Optional(rate))
                    }
                }
                if let rotation = model.current.first(where: { $0.id == selectedID })?.rotation {
                    HStack {
                        Text("Rotation: \(rotation.formatted())°").foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Displays Settings") { openDisplaysSettings() }
                    }
                    .font(.callout)
                }
            }
        }
    }

    private func reloadRates() {
        rates = model.refreshRates(for: selectedID)
    }

    private func openDisplaysSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension"),
              NSWorkspace.shared.open(url) else {
            model.error = "Open System Settings → Displays to change rotation."
            return
        }
    }

    private func gesture(for id: String, in workspace: Workspace) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("layoutWorkspace"))
            .updating($drag) { value, state, _ in
                state = Drag(id: id, translation: value.translation)
            }
            .onEnded { value in
                guard !model.busy, draft.displays.count > 1 else { return }
                selectedID = id
                if let snapped = proposal(for: Drag(id: id, translation: value.translation), in: workspace) {
                    draft = snapped
                    feedback = nil
                } else {
                    feedback = "Drop near a free edge and keep all displays connected."
                }
            }
    }

    private func proposal(for drag: Drag, in workspace: Workspace) -> LayoutDraft? {
        guard let display = draft.displays.first(where: { $0.id == drag.id }) else { return nil }
        let origin = CGPoint(x: display.bounds.minX + drag.translation.width / workspace.scale,
                             y: display.bounds.minY + drag.translation.height / workspace.scale)
        var proposed = draft
        return proposed.move(drag.id, to: origin, snapDistance: 30 / workspace.scale,
                             alignmentDistance: 8 / workspace.scale) ? proposed : nil
    }

    private func tile(_ display: Display, moving: Bool, valid: Bool, size: CGSize) -> some View {
        let color: Color = moving && !valid ? .orange : .accentColor
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(moving ? 0.32 : display.builtIn ? 0.24 : 0.12))
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(color.opacity(moving || display.id == selectedID ? 1 : 0.6),
                              lineWidth: moving || display.id == selectedID ? 2 : 1)
            if display.primary && size.height >= 12 {
                Capsule().fill(color).frame(width: min(size.width * 0.4, 32), height: 2).padding(.top, 4)
            }
            if size.width >= 34 && size.height >= 26 {
                VStack(spacing: 2) {
                    Image(systemName: display.builtIn ? "laptopcomputer" : "display")
                    if size.width >= 60 && size.height >= 46 {
                        Text(display.name).font(.caption2).lineLimit(1)
                    }
                }
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .help(display.primary ? "\(display.name) · Primary" : display.name)
        .accessibilityLabel(display.primary ? "\(display.name), primary" : display.name)
    }

    private func save() {
        if model.saveDraft(draft, name: name) {
            feedback = "Saved “\(name.trimmingCharacters(in: .whitespacesAndNewlines))”."
            name = ""
        }
    }

    private struct Workspace {
        let bounds: CGRect
        let scale: CGFloat
        let offset: CGPoint

        init(displays: [Display], size: CGSize) {
            bounds = displays.reduce(CGRect.null) { $0.union($1.bounds) }
            let widest = displays.map { $0.bounds.width }.max() ?? 0
            let tallest = displays.map { $0.bounds.height }.max() ?? 0
            // Reserve room on both sides of the layout for the largest display.
            let width = max(size.width - 16, 1)
            let height = max(size.height - 16, 1)
            scale = min(width / (bounds.width + 2 * widest), height / (bounds.height + 2 * tallest))
            offset = CGPoint(x: (size.width - bounds.width * scale) / 2,
                             y: (size.height - bounds.height * scale) / 2)
        }

        func rect(for display: CGRect) -> CGRect {
            CGRect(x: offset.x + (display.minX - bounds.minX) * scale,
                   y: offset.y + (display.minY - bounds.minY) * scale,
                   width: display.width * scale, height: display.height * scale)
        }
    }
}

import SwiftUI

struct LayoutPreview: View {
    let displays: [Display]
    let active: Bool

    var body: some View {
        Canvas { context, size in
            guard let first = displays.first else { return }
            let bounds = displays.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
            guard bounds.width > 0, bounds.height > 0 else { return }
            let scale = min((size.width - 8) / bounds.width, (size.height - 8) / bounds.height)
            let left = (size.width - bounds.width * scale) / 2
            let top = (size.height - bounds.height * scale) / 2
            for display in displays {
                let rect = CGRect(x: left + (display.bounds.minX - bounds.minX) * scale,
                                  y: top + (display.bounds.minY - bounds.minY) * scale,
                                  width: display.bounds.width * scale,
                                  height: display.bounds.height * scale)
                let color = active ? Color.accentColor : Color.secondary
                let shape = Path(roundedRect: rect.insetBy(dx: 0.7, dy: 0.7), cornerRadius: 2)
                context.fill(shape, with: .color(color.opacity(display.builtIn ? 0.34 : 0.12)))
                context.stroke(shape, with: .color(color), lineWidth: 0.9)
                if display.primary && rect.width > 8 && rect.height > 6 {
                    let bar = CGRect(x: rect.midX - rect.width * 0.23, y: rect.minY + 3,
                                     width: rect.width * 0.46, height: 1.5)
                    context.fill(Path(roundedRect: bar, cornerRadius: 0.75), with: .color(color))
                }
            }
        }
        .frame(width: 86, height: 49)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityHidden(true)
    }
}

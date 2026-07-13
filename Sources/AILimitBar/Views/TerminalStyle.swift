import AppKit
import SwiftUI

enum TerminalTheme {
    static let surface = adaptiveColor(
        light: NSColor(calibratedRed: 0.97, green: 0.96, blue: 0.91, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.13, alpha: 1)
    )
    static let primary = adaptiveColor(
        light: NSColor(calibratedRed: 0.18, green: 0.16, blue: 0.11, alpha: 1),
        dark: NSColor(calibratedRed: 0.91, green: 0.87, blue: 0.74, alpha: 1)
    )
    static let secondary = adaptiveColor(
        light: NSColor(calibratedRed: 0.43, green: 0.39, blue: 0.29, alpha: 1),
        dark: NSColor(calibratedRed: 0.63, green: 0.59, blue: 0.48, alpha: 1)
    )
    static let border = adaptiveColor(
        light: NSColor(calibratedRed: 0.48, green: 0.43, blue: 0.30, alpha: 1),
        dark: NSColor(calibratedRed: 0.67, green: 0.61, blue: 0.43, alpha: 1)
    )
    static let healthy = adaptiveColor(
        light: NSColor(calibratedRed: 0.18, green: 0.47, blue: 0.24, alpha: 1),
        dark: NSColor(calibratedRed: 0.40, green: 0.70, blue: 0.40, alpha: 1)
    )
    static let warning = adaptiveColor(
        light: NSColor(calibratedRed: 0.67, green: 0.36, blue: 0.04, alpha: 1),
        dark: NSColor(calibratedRed: 0.91, green: 0.59, blue: 0.11, alpha: 1)
    )
    static let error = adaptiveColor(
        light: NSColor(calibratedRed: 0.65, green: 0.16, blue: 0.14, alpha: 1),
        dark: NSColor(calibratedRed: 0.91, green: 0.39, blue: 0.35, alpha: 1)
    )

    static let titleFont = Font.system(size: 14, weight: .bold, design: .monospaced)
    static let legendFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let bodyFont = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let emphasizedBodyFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
    static let captionFont = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let detailLabelFont = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let detailValueFont = Font.system(size: 13, weight: .medium, design: .monospaced)

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }
}

struct TerminalRule: View {
    var body: some View {
        Rectangle()
            .fill(TerminalTheme.border.opacity(0.62))
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct TerminalStatusMeter: View {
    let value: Double
    let tint: Color
    let accessibilityLabel: String
    let accessibilityValue: String

    private var normalizedValue: Double {
        min(max(value, 0), 100) / 100
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .strokeBorder(TerminalTheme.border, lineWidth: 1)

            GeometryReader { proxy in
                Rectangle()
                    .fill(tint)
                    .frame(
                        width: max(0, (proxy.size.width - 2) * normalizedValue),
                        height: max(0, proxy.size.height - 2)
                    )
                    .padding(1)
            }
        }
        .frame(height: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }
}

struct TerminalIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? TerminalTheme.primary : TerminalTheme.secondary)
            .frame(minWidth: 22, minHeight: 22)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? TerminalTheme.primary.opacity(0.18) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .terminalControlHighlight()
    }
}

struct TerminalTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TerminalTheme.bodyFont)
            .foregroundStyle(configuration.isPressed ? TerminalTheme.primary : TerminalTheme.secondary)
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? TerminalTheme.primary.opacity(0.18) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .terminalControlHighlight()
    }
}

private struct TerminalControlHighlight: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isHovering ? TerminalTheme.primary.opacity(0.12) : .clear)
            )
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

private extension View {
    func terminalControlHighlight() -> some View {
        modifier(TerminalControlHighlight())
    }
}

struct TerminalNoteBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(TerminalTheme.detailLabelFont)
                .foregroundStyle(TerminalTheme.secondary)

            content()
        }
        .padding(8)
        .background(TerminalTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(TerminalTheme.border.opacity(0.8), lineWidth: 1)
        }
    }
}

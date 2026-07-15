import AppKit
import SwiftUI

struct AboutView: View {
    private let buildInformation: AboutBuildInformation

    init(buildInformation: AboutBuildInformation = .current) {
        self.buildInformation = buildInformation
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(spacing: 5) {
                Text("AI Limitbar")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(TerminalTheme.primary)

                Text(buildInformation.displayText)
                    .font(TerminalTheme.bodyFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .accessibilityLabel("Build information")
                    .accessibilityValue(buildInformation.displayText)
            }

            VStack(spacing: 8) {
                externalLink(
                    "Open GitHub",
                    destination: AboutLinks.github,
                    accessibilityLabel: "Open AI Limitbar on GitHub"
                )

                Text("Feedback")
                    .font(TerminalTheme.detailLabelFont)
                    .foregroundStyle(TerminalTheme.secondary)

                HStack(spacing: 8) {
                    externalLink(
                        "Report an issue",
                        destination: AboutLinks.issue,
                        accessibilityLabel: "Report an AI Limitbar issue on GitHub"
                    )

                    externalLink(
                        "Email",
                        destination: AboutLinks.email,
                        accessibilityLabel: "Email the AI Limitbar developer"
                    )

                    externalLink(
                        "Telegram",
                        destination: AboutLinks.telegram,
                        accessibilityLabel: "Message the AI Limitbar developer on Telegram"
                    )
                }

                Text("If AI Limitbar is useful, thank you for supporting its development.")
                    .font(TerminalTheme.captionFont)
                    .foregroundStyle(TerminalTheme.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                externalLink(
                    "Support on Boosty",
                    destination: AboutLinks.boosty,
                    accessibilityLabel: "Support AI Limitbar on Boosty"
                )
            }
        }
        .padding(24)
        .frame(
            width: AboutWindowConfiguration.preferredSize.width,
            height: AboutWindowConfiguration.preferredSize.height
        )
        .background(TerminalTheme.surface)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About AI Limitbar")
    }

    private func externalLink(
        _ title: String,
        destination: URL,
        accessibilityLabel: String
    ) -> some View {
        Link(destination: destination) {
            Text(title)
                .font(TerminalTheme.bodyFont)
                .foregroundStyle(TerminalTheme.primary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(TerminalTheme.border.opacity(0.8), lineWidth: 1)
                }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

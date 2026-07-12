import AILimitBarCore
import Darwin
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3, arguments[1] == "--snapshot-path" else {
    fputs("Usage: AILimitBarClaudeStatusLine --snapshot-path <path>\n", stderr)
    exit(EXIT_FAILURE)
}

let data = FileHandle.standardInput.readDataToEndOfFile()
let snapshotURL = URL(fileURLWithPath: (arguments[2] as NSString).expandingTildeInPath)
let writer = ClaudeCodeStatusLineSnapshotWriter()

do {
    let snapshot = try writer.writeSnapshot(from: data, to: snapshotURL)
    let values = snapshot.limitWindows.compactMap { window -> String? in
        guard let usedPercent = window.usedPercent else { return nil }
        let shortName = window.id == "rolling-5-hour" ? "5h" : "7d"
        return "\(shortName) \(Int(usedPercent.rounded()))%"
    }
    print(values.isEmpty ? "AI Limits unavailable" : "AI Limits · \(values.joined(separator: " · "))")
} catch {
    fputs("AI Limitbar: \(error.localizedDescription)\n", stderr)
    print("AI Limits unavailable")
    exit(EXIT_FAILURE)
}

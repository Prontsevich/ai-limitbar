import Foundation

struct AppLaunchOptions {
    static let storageDirectoryArgument = "--ai-limitbar-storage-directory"

    let storageDirectory: URL?

    init(arguments: [String] = CommandLine.arguments) {
        guard let argumentIndex = arguments.firstIndex(of: Self.storageDirectoryArgument) else {
            storageDirectory = nil
            return
        }

        let valueIndex = arguments.index(after: argumentIndex)
        guard valueIndex < arguments.endIndex else {
            fatalError("Missing value for \(Self.storageDirectoryArgument)")
        }

        let path = arguments[valueIndex]
        guard path.hasPrefix("/") else {
            fatalError("The value for \(Self.storageDirectoryArgument) must be an absolute path")
        }

        storageDirectory = URL(fileURLWithPath: path, isDirectory: true)
    }
}

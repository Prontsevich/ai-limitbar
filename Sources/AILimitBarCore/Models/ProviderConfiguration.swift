import Foundation

public enum ProviderSourceMode: String, Codable, CaseIterable, Sendable {
    case manual
    case claudeStatusLine = "claude-status-line"
    case ollamaWebPage = "ollama-web-page"
    case appServer = "app-server"

    public var displayName: String {
        switch self {
        case .manual: "Manual"
        case .claudeStatusLine: "Managed statusLine"
        case .ollamaWebPage: "Experimental web page"
        case .appServer: "Experimental app-server"
        }
    }

    public var isExperimental: Bool {
        switch self {
        case .ollamaWebPage, .appServer:
            true
        case .manual, .claudeStatusLine:
            false
        }
    }

    public static func defaultMode(for providerID: String) -> ProviderSourceMode {
        switch providerID {
        case "claude-code":
            .claudeStatusLine
        case "ollama-cloud":
            .ollamaWebPage
        case "openai-codex":
            .appServer
        default:
            .manual
        }
    }

    public static func resolvedMode(
        _ requestedMode: ProviderSourceMode?,
        for providerID: String
    ) -> ProviderSourceMode {
        let providerDefault = defaultMode(for: providerID)
        return providerDefault == .manual ? requestedMode ?? .manual : providerDefault
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        switch try container.decode(String.self) {
        case "local-snapshot":
            self = .claudeStatusLine
        case let rawValue where Self(rawValue: rawValue) != nil:
            self = Self(rawValue: rawValue)!
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported provider source mode."
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ProviderAccount: Codable, Identifiable, Equatable, Sendable {
    public static let defaultAccountID = "default"
    public static let defaultDisplayName = "Default"

    public var id: String { accountKey }
    public var accountKey: String { "\(providerID):\(accountID)" }

    public let providerID: String
    public let accountID: String
    public var displayName: String
    public var isEnabled: Bool
    public var sourceMode: ProviderSourceMode
    public var localSnapshotPath: String?
    public var webDataStoreID: UUID?
    public var codexExecutablePath: String?

    public init(
        providerID: String,
        accountID: String = ProviderAccount.defaultAccountID,
        displayName: String = ProviderAccount.defaultDisplayName,
        isEnabled: Bool,
        sourceMode: ProviderSourceMode? = nil,
        localSnapshotPath: String? = nil,
        webDataStoreID: UUID? = nil,
        codexExecutablePath: String? = nil
    ) {
        self.providerID = providerID
        self.accountID = accountID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sourceMode = ProviderSourceMode.resolvedMode(sourceMode, for: providerID)
        self.localSnapshotPath = localSnapshotPath
        self.webDataStoreID = webDataStoreID
        self.codexExecutablePath = codexExecutablePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decode(String.self, forKey: .providerID)
        accountID = try container.decode(String.self, forKey: .accountID)
        displayName = try container.decode(String.self, forKey: .displayName)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        sourceMode = ProviderSourceMode.resolvedMode(
            try container.decodeIfPresent(ProviderSourceMode.self, forKey: .sourceMode),
            for: providerID
        )
        localSnapshotPath = try container.decodeIfPresent(String.self, forKey: .localSnapshotPath)
        webDataStoreID = try container.decodeIfPresent(UUID.self, forKey: .webDataStoreID)
        codexExecutablePath = try container.decodeIfPresent(String.self, forKey: .codexExecutablePath)
    }
}

import Foundation

public enum ProviderSourceMode: String, Codable, CaseIterable, Sendable {
    case manual
    case localSnapshot = "local-snapshot"

    public var displayName: String {
        switch self {
        case .manual: "Manual"
        case .localSnapshot: "Local snapshot"
        }
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

    public init(
        providerID: String,
        accountID: String = ProviderAccount.defaultAccountID,
        displayName: String = ProviderAccount.defaultDisplayName,
        isEnabled: Bool,
        sourceMode: ProviderSourceMode = .manual,
        localSnapshotPath: String? = nil
    ) {
        self.providerID = providerID
        self.accountID = accountID
        self.displayName = displayName
        self.isEnabled = isEnabled
        self.sourceMode = sourceMode
        self.localSnapshotPath = localSnapshotPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decode(String.self, forKey: .providerID)
        accountID = try container.decode(String.self, forKey: .accountID)
        displayName = try container.decode(String.self, forKey: .displayName)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        sourceMode = try container.decodeIfPresent(ProviderSourceMode.self, forKey: .sourceMode) ?? .manual
        localSnapshotPath = try container.decodeIfPresent(String.self, forKey: .localSnapshotPath)
    }
}

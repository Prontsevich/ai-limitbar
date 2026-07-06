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

public struct ProviderConfiguration: Codable, Identifiable, Equatable, Sendable {
    public var id: String { providerID }

    public let providerID: String
    public var isEnabled: Bool
    public var sourceMode: ProviderSourceMode
    public var localSnapshotPath: String?

    public init(
        providerID: String,
        isEnabled: Bool,
        sourceMode: ProviderSourceMode = .manual,
        localSnapshotPath: String? = nil
    ) {
        self.providerID = providerID
        self.isEnabled = isEnabled
        self.sourceMode = sourceMode
        self.localSnapshotPath = localSnapshotPath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decode(String.self, forKey: .providerID)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        sourceMode = try container.decodeIfPresent(ProviderSourceMode.self, forKey: .sourceMode) ?? .manual
        localSnapshotPath = try container.decodeIfPresent(String.self, forKey: .localSnapshotPath)
    }
}

import Foundation

public enum MiniMaxProviderContract {
    public static let providerID = "minimax"
    public static let surfaceID = "token-plan"
    public static let sourceID = "token-plan-remains-api"
    public static let providerUnitID = "minimax.included-usage"

    public static let surface = ProviderSurface(
        providerID: providerID,
        surfaceID: surfaceID,
        displayName: "MiniMax Global Token Plan",
        interactionModel: .subscription,
        regions: [
            RegionDescriptor(regionID: "global", displayName: "Global")
        ],
        accountContextKinds: [.team],
        capabilities: ["quota-windows", "reset-schedule"]
    )

    public static let source = SourceDescriptor(
        providerID: providerID,
        surfaceID: surfaceID,
        sourceID: sourceID,
        displayName: "MiniMax Token Plan remains API",
        kind: .documentedRemoteAPI,
        authority: .providerReported,
        maturity: .experimental,
        defaultConfidence: .live,
        freshnessPolicy: FreshnessPolicy(kind: .unknown),
        capabilities: ["quota-windows", "reset-schedule"],
        authRequirement: AuthRequirement(
            category: .subscriptionKey,
            privilege: .leastPrivilege,
            storageBoundary: .keychain
        )
    )
}

public enum MiniMaxModelRowMappingError:
    Error,
    LocalizedError,
    Equatable,
    Sendable
{
    case invalidEntry
    case duplicateProviderName
    case duplicateStableID

    public var errorDescription: String? {
        switch self {
        case .invalidEntry:
            "The MiniMax reviewed row mapping is invalid."
        case .duplicateProviderName:
            "The MiniMax reviewed row mapping contains a duplicate provider row."
        case .duplicateStableID:
            "The MiniMax reviewed row mapping contains a duplicate stable identifier."
        }
    }
}

public struct MiniMaxReviewedModelRow:
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible
{
    fileprivate let providerName: String
    public let stableID: String
    public let displayName: String

    public init(
        providerName: String,
        stableID: String,
        displayName: String
    ) throws {
        guard !providerName.isEmpty,
              Self.isStableID(stableID),
              !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw MiniMaxModelRowMappingError.invalidEntry
        }
        self.providerName = providerName
        self.stableID = stableID
        self.displayName = displayName
    }

    public var description: String {
        "<redacted MiniMax reviewed model row: \(stableID)>"
    }

    public var debugDescription: String { description }

    private static func isStableID(_ value: String) -> Bool {
        value.range(
            of: #"^[a-z0-9]+(?:-[a-z0-9]+)*$"#,
            options: .regularExpression
        ) != nil
    }
}

public struct MiniMaxModelRowMapping: Sendable {
    private let rowsByProviderName: [String: MiniMaxReviewedModelRow]

    public init(rows: [MiniMaxReviewedModelRow]) throws {
        var providerNames = Set<String>()
        var stableIDs = Set<String>()
        var mappedRows: [String: MiniMaxReviewedModelRow] = [:]

        for row in rows {
            guard providerNames.insert(row.providerName).inserted else {
                throw MiniMaxModelRowMappingError.duplicateProviderName
            }
            guard stableIDs.insert(row.stableID).inserted else {
                throw MiniMaxModelRowMappingError.duplicateStableID
            }
            mappedRows[row.providerName] = row
        }
        rowsByProviderName = mappedRows
    }

    func reviewedRow(
        forProviderName providerName: String
    ) -> MiniMaxReviewedModelRow? {
        rowsByProviderName[providerName]
    }
}

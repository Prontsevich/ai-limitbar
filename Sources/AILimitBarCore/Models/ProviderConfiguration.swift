import Foundation

public struct ProviderConfiguration: Codable, Identifiable, Equatable, Sendable {
    public var id: String { providerID }

    public let providerID: String
    public var isEnabled: Bool

    public init(providerID: String, isEnabled: Bool) {
        self.providerID = providerID
        self.isEnabled = isEnabled
    }
}

import Foundation

public protocol KeychainService: Sendable {
    func readCredential(account: String) throws -> String?
    func saveCredential(_ credential: String, account: String) throws
    func deleteCredential(account: String) throws
}

public struct DisabledKeychainService: KeychainService {
    public init() {}

    public func readCredential(account: String) throws -> String? {
        nil
    }

    public func saveCredential(_ credential: String, account: String) throws {
        throw KeychainServiceError.credentialsDisabled
    }

    public func deleteCredential(account: String) throws {}
}

public enum KeychainServiceError: Error, LocalizedError, Sendable {
    case credentialsDisabled

    public var errorDescription: String? {
        switch self {
        case .credentialsDisabled:
            "Credential entry is disabled until provider requirements are verified."
        }
    }
}

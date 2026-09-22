import Foundation
import Security

enum CardCryptoAlgorithm: String, Codable, CaseIterable {
    case aes128 = "AES-128"
    case des = "DES"
    case twoKey3DES = "2K3DES"
    case threeKey3DES = "3K3DES"
    case other = "Other"
}

struct KeyVaultEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var algorithm: CardCryptoAlgorithm
    var cardGenome: String?
}

/// Stores only user-supplied, authorized keys in the iOS Keychain.
/// Secret bytes never appear in NFCCard logs, exports, Card Genome, or snapshots.
actor KeyVault {
    static let shared = KeyVault()
    private let service = "com.rashad.nfccard.keyvault"

    private init() {}

    func save(secret: Data, for entry: KeyVaultEntry) throws {
        let account = entry.id.uuidString
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecValueData as String] = secret
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyVaultError.osStatus(status) }
    }

    func secret(for entry: KeyVaultEntry) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: entry.id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeyVaultError.osStatus(status) }
        return result as? Data
    }

    func delete(_ entry: KeyVaultEntry) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: entry.id.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeyVaultError.osStatus(status) }
    }
}

enum KeyVaultError: Error {
    case osStatus(OSStatus)
}

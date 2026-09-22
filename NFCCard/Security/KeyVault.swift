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
        let query = baseQuery(for: entry)
        let update: [String: Any] = [
            kSecValueData as String: secret,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeyVaultError.osStatus(updateStatus) }

        var add = query
        add[kSecValueData as String] = secret
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeyVaultError.osStatus(addStatus) }
    }

    func secret(for entry: KeyVaultEntry) throws -> Data? {
        var query = baseQuery(for: entry)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeyVaultError.osStatus(status) }
        return result as? Data
    }

    func delete(_ entry: KeyVaultEntry) throws {
        let status = SecItemDelete(baseQuery(for: entry) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyVaultError.osStatus(status)
        }
    }

    private func baseQuery(for entry: KeyVaultEntry) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: entry.id.uuidString
        ]
    }
}

enum KeyVaultError: Error {
    case osStatus(OSStatus)
}

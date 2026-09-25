import Foundation

/// An unsigned DISPLAY pass source. Only an issuer-side signer may supply the
/// Pass Type ID, Team ID, certificate and signature. No NFC credential is made.
struct WalletPassSource: Codable, Equatable {
    struct Field: Codable, Equatable {
        let key: String
        let label: String
        let value: String
    }

    struct Generic: Codable, Equatable {
        let headerFields: [Field]
        let primaryFields: [Field]
        let secondaryFields: [Field]
        let auxiliaryFields: [Field]
        let backFields: [Field]
    }

    let formatVersion: Int
    let serialNumber: String
    let organizationName: String
    let description: String
    let logoText: String
    let backgroundColor: String
    let foregroundColor: String
    let labelColor: String
    let generic: Generic

    static let limitation = "Display only. This pass does not emulate the scanned card, transmit its UID, or unlock an ACID/access-control reader."

    init(card: NFCCardProfile, title: String, includeIdentifier: Bool) {
        formatVersion = 1
        // The snapshot UUID, not the access-card UID, identifies the Wallet pass.
        serialNumber = "nfccard-" + card.id.uuidString.lowercased()
        organizationName = "NFCCard"
        description = "NFC card information — display only"
        logoText = "NFCCard"
        backgroundColor = "rgb(15, 18, 24)"
        foregroundColor = "rgb(255, 255, 255)"
        labelColor = "rgb(0, 145, 255)"
        var back = [Field(key: "limitation", label: "NOT AN ACCESS CREDENTIAL", value: Self.limitation)]
        if let subtype = card.subtype, !subtype.isEmpty {
            back.append(Field(key: "subtype", label: "Detected subtype / AID", value: Self.clean(subtype, limit: 256)))
        }
        var auxiliary: [Field] = []
        if includeIdentifier, let uid = card.uidHex, !uid.isEmpty {
            auxiliary.append(Field(key: "identifier", label: "PUBLIC CARD IDENTIFIER", value: Self.clean(uid, limit: 128)))
        }
        generic = Generic(
            headerFields: [Field(key: "purpose", label: "PURPOSE", value: "DISPLAY ONLY")],
            primaryFields: [Field(key: "name", label: "CARD", value: Self.displayTitle(title))],
            secondaryFields: [Field(key: "technology", label: "TECHNOLOGY", value: Self.clean(card.technology, limit: 80))],
            auxiliaryFields: auxiliary,
            backFields: back
        )
    }

    static func displayTitle(_ value: String) -> String {
        let result = clean(value, limit: 80)
        return result.isEmpty || result == "Unknown Card" ? "NFC Card" : result
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let scalars = value.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let text = String(String.UnicodeScalarView(scalars))
        return String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

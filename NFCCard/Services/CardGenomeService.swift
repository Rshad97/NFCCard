import Foundation
import CryptoKit

enum CardGenomeService {
    static func fingerprint(_ card: NFCCardProfile) -> String {
        var components: [String] = [
            "technology=\(card.technology)",
            "subtype=\(card.subtype ?? "")",
            "uid=\(card.uidHex ?? "")"
        ]

        for key in card.details.keys.sorted() {
            components.append("detail.\(key)=\(card.details[key] ?? "")")
        }

        if let ndef = card.ndef {
            components.append("ndef.access=\(ndef.access.rawValue)")
            components.append("ndef.capacity=\(ndef.capacity)")
        }

        let bytes = Data(components.joined(separator: "\n").utf8)
        let digest = SHA256.hash(data: bytes)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

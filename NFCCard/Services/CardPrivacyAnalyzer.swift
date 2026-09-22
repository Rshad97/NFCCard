import Foundation

enum CardPrivacyAnalyzer {
    static func analyze(_ card: NFCCardProfile) -> [NFCPrivacyInsight] {
        var results: [NFCPrivacyInsight] = []

        if let uid = card.uidHex, !uid.isEmpty {
            results.append(
                NFCPrivacyInsight(
                    title: "Identifier exposed",
                    detail: "The tag exposes an identifier to compatible readers. Whether it is permanent or randomized depends on the card family and configuration.",
                    severity: .notice
                )
            )
        }

        if let ndef = card.ndef, !ndef.records.isEmpty {
            results.append(
                NFCPrivacyInsight(
                    title: "Public NDEF content",
                    detail: "The tag contains NDEF records readable without an authenticated session. Review the record previews before sharing exports.",
                    severity: .warning
                )
            )
        }

        if card.details.values.contains(where: { !$0.isEmpty && $0 != "—" }) {
            results.append(
                NFCPrivacyInsight(
                    title: "Protocol metadata visible",
                    detail: "Protocol metadata such as historical bytes, manufacturer fields, or system codes can help fingerprint a card family.",
                    severity: .info
                )
            )
        }

        if results.isEmpty {
            results.append(
                NFCPrivacyInsight(
                    title: "Limited public metadata",
                    detail: "This scan exposed little unauthenticated metadata through the APIs available to NFCCard.",
                    severity: .info
                )
            )
        }

        return results
    }
}

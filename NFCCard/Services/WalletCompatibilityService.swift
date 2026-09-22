import Foundation

struct WalletCompatibilityResult: Identifiable {
    let id = UUID()
    let title: String
    let status: Status
    let explanation: String

    enum Status: String {
        case supported = "Supported"
        case conditional = "Conditional"
        case unavailable = "Unavailable"
    }
}

enum WalletCompatibilityService {
    static func evaluate(_ card: NFCCardProfile) -> [WalletCompatibilityResult] {
        var results: [WalletCompatibilityResult] = []

        results.append(
            WalletCompatibilityResult(
                title: "Apple Wallet pass",
                status: .conditional,
                explanation: "NFCCard can prepare a Wallet pass route when the use case has a legitimate barcode, membership identifier, ticket, or supported pass payload. A signed pass still requires the appropriate PassKit certificate/backend signing flow."
            )
        )

        results.append(
            WalletCompatibilityResult(
                title: "Wallet NFC / VAS",
                status: .conditional,
                explanation: "Contactless Wallet passes require Apple-approved NFC/VAS capabilities and compatible reader infrastructure. This is provisioning, not generic cloning of a physical card."
            )
        )

        results.append(
            WalletCompatibilityResult(
                title: "NFC & Secure Element credential",
                status: .conditional,
                explanation: "Apple's NFC & SE Platform can provision supported secure credentials when the developer, issuer, use case, territory, entitlement, applet, and backend meet Apple's requirements."
            )
        )

        let hasISO7816Route = card.capabilities.contains { $0.kind == .iso7816APDU && $0.available }
        results.append(
            WalletCompatibilityResult(
                title: "Host Card Emulation (CardSession)",
                status: hasISO7816Route ? .conditional : .unavailable,
                explanation: "Apple exposes ISO 7816 HCE only for eligible use cases, regions, devices, and managed entitlements. A compatible card protocol does not by itself make the original credential emulatable."
            )
        )

        results.append(
            WalletCompatibilityResult(
                title: "Generic physical-card clone",
                status: .unavailable,
                explanation: "iPhone and Apple Wallet do not provide a universal path to emulate every NFC/RFID card, proprietary protocol, or protected credential."
            )
        )

        return results
    }
}

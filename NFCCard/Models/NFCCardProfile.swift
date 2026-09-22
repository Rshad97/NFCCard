import Foundation

struct NFCCardProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var technology: String
    var uidHex: String?
    var subtype: String?
    var details: [String: String]
    var scannedAt: Date

    var genome: String?
    var capabilities: [NFCCapability]
    var ndef: NDEFMetadata?
    var privacyInsights: [NFCPrivacyInsight]
    var matchedModules: [String]

    init(
        id: UUID = UUID(),
        name: String = "Unknown Card",
        technology: String,
        uidHex: String? = nil,
        subtype: String? = nil,
        details: [String: String] = [:],
        scannedAt: Date = .now,
        genome: String? = nil,
        capabilities: [NFCCapability] = [],
        ndef: NDEFMetadata? = nil,
        privacyInsights: [NFCPrivacyInsight] = [],
        matchedModules: [String] = []
    ) {
        self.id = id
        self.name = name
        self.technology = technology
        self.uidHex = uidHex
        self.subtype = subtype
        self.details = details
        self.scannedAt = scannedAt
        self.genome = genome
        self.capabilities = capabilities
        self.ndef = ndef
        self.privacyInsights = privacyInsights
        self.matchedModules = matchedModules
    }
}

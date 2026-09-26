import Foundation

enum NFCReadOnlyProbeKind: String, Codable, Hashable {
    case desfireGetVersion = "DESFire GetVersion"
}

struct NFCReadOnlyProbeRequest: Equatable {
    let kind: NFCReadOnlyProbeKind
    let expectedUIDHex: String?
}

struct NFCReadOnlyProbeResult: Codable, Hashable {
    let kind: NFCReadOnlyProbeKind
    let observedUIDHex: String?
    let recognized: Bool
    let summary: String
    let statusWords: [String]
    let rawResponseHex: String
    let details: [String: String]

    var statusText: String {
        statusWords.isEmpty ? "No status word" : statusWords.joined(separator: " → ")
    }
}

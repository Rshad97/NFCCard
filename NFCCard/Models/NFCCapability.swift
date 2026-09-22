import Foundation

enum NFCCapabilityKind: String, Codable, CaseIterable, Hashable {
    case ndefRead
    case ndefWrite
    case iso7816APDU
    case mifareNative
    case iso15693Commands
    case felicaCommands
    case stableIdentifier
}

struct NFCCapability: Identifiable, Codable, Hashable {
    var id: String { kind.rawValue }
    let kind: NFCCapabilityKind
    let title: String
    let detail: String
    let available: Bool
}

import Foundation

enum CapabilityMapService {
    static func capabilities(for card: NFCCardProfile) -> [NFCCapability] {
        let technology = card.technology.lowercased()
        let subtype = (card.subtype ?? "").lowercased()
        let ndef = card.ndef

        var items: [NFCCapability] = []

        if technology.contains("iso 7816") || subtype.contains("desfire") {
            items.append(.init(kind: .iso7816APDU, title: "ISO 7816 APDU", detail: "APDU transport is available for compatible applications and permitted AIDs.", available: true))
        }

        if technology.contains("mifare") {
            items.append(.init(kind: .mifareNative, title: "MIFARE native commands", detail: "Core NFC exposes native MIFARE command transport for supported families.", available: true))
        }

        if technology.contains("15693") {
            items.append(.init(kind: .iso15693Commands, title: "ISO 15693 commands", detail: "ISO 15693 block and custom commands are available through Core NFC.", available: true))
        }

        if technology.contains("felica") {
            items.append(.init(kind: .felicaCommands, title: "FeliCa commands", detail: "FeliCa command transport is available through Core NFC.", available: true))
        }

        if let ndef {
            items.append(.init(kind: .ndefRead, title: "NDEF read", detail: "NDEF status: \(ndef.access.rawValue), capacity \(ndef.capacity) bytes.", available: ndef.access != .unsupported))
            items.append(.init(kind: .ndefWrite, title: "NDEF write", detail: "Write availability is based on the tag-reported NDEF access mode.", available: ndef.access == .readWrite))
        }

        items.append(.init(kind: .stableIdentifier, title: "Identifier visible", detail: "A tag identifier was returned during this scan.", available: card.uidHex?.isEmpty == false))
        return items
    }
}

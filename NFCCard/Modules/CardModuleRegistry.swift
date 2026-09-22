import Foundation

enum CardModuleRegistry {
    static let modules: [any CardModule] = [
        NDEFModule(),
        ISO7816Module(),
        MIFAREModule(),
        ISO15693Module(),
        FeliCaModule()
    ]

    static func matches(for card: NFCCardProfile) -> [String] {
        modules.filter { $0.matches(card) }.map { $0.descriptor.name }
    }
}

private struct NDEFModule: CardModule {
    let descriptor = CardModuleDescriptor(id: "ndef", name: "NDEF Lens", family: "NFC Forum", summary: "NDEF status, capacity and public record summaries")
    func matches(_ card: NFCCardProfile) -> Bool { card.ndef?.access != .unsupported && card.ndef != nil }
}

private struct ISO7816Module: CardModule {
    let descriptor = CardModuleDescriptor(id: "iso7816", name: "APDU Lens", family: "ISO 7816", summary: "ISO 7816 application and APDU diagnostics")
    func matches(_ card: NFCCardProfile) -> Bool { card.technology.lowercased().contains("7816") || (card.subtype ?? "").lowercased().contains("desfire") }
}

private struct MIFAREModule: CardModule {
    let descriptor = CardModuleDescriptor(id: "mifare", name: "MIFARE Lens", family: "MIFARE", summary: "MIFARE family identification and safe protocol diagnostics")
    func matches(_ card: NFCCardProfile) -> Bool { card.technology.lowercased().contains("mifare") }
}

private struct ISO15693Module: CardModule {
    let descriptor = CardModuleDescriptor(id: "iso15693", name: "Vicinity Lens", family: "ISO 15693", summary: "Vicinity-card identifiers and block-level capability mapping")
    func matches(_ card: NFCCardProfile) -> Bool { card.technology.lowercased().contains("15693") }
}

private struct FeliCaModule: CardModule {
    let descriptor = CardModuleDescriptor(id: "felica", name: "FeliCa Lens", family: "FeliCa", summary: "System Code, PMm and FeliCa transport diagnostics")
    func matches(_ card: NFCCardProfile) -> Bool { card.technology.lowercased().contains("felica") }
}

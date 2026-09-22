import Foundation

enum ProtocolAtlasService {
    static func analyze(_ card: NFCCardProfile) -> ProtocolAtlasReport {
        let tech = card.technology.lowercased()
        let subtype = (card.subtype ?? "").lowercased()
        var evidence: [ProtocolEvidence] = []
        var probes: [String] = []
        var limitations: [String] = [
            "Identification is evidence-based. Exact silicon revision may require a standards-compliant read-only vendor command."
        ]

        var family = card.technology
        var variant = card.subtype ?? "Unknown variant"
        var baseConfidence = 0.55

        if tech.contains("mifare") {
            family = "MIFARE / ISO 14443"
            evidence.append(.init(
                source: "Core NFC",
                observation: "Tag surfaced through the MIFARE transport",
                interpretation: "The iPhone classified this tag in the MIFARE family.",
                weight: 0.30
            ))

            if subtype.contains("desfire") {
                family = "MIFARE DESFire"
                variant = "DESFire family"
                baseConfidence = 0.94
                probes = [
                    "DESFire GetVersion (read-only)",
                    "Inspect publicly readable application metadata",
                    "Check NDEF mapping without authentication"
                ]
                limitations.append("EV1/EV2/EV3 revision should be confirmed from GetVersion bytes rather than inferred from UID or appearance.")
            } else if subtype.contains("ultralight") {
                family = "MIFARE Ultralight / NTAG"
                variant = "Ultralight-compatible family"
                baseConfidence = 0.88
                probes = [
                    "GET_VERSION / version information where supported",
                    "Read capability container",
                    "Inspect NDEF memory layout"
                ]
                limitations.append("Ultralight-compatible tags include several NTAG and Ultralight generations with similar transport behavior.")
            } else if subtype.contains("plus") {
                family = "MIFARE Plus"
                variant = "Plus family"
                baseConfidence = 0.88
                probes = [
                    "Collect non-mutating version/capability metadata where exposed",
                    "Inspect NDEF mapping if configured"
                ]
            } else {
                baseConfidence = 0.68
                probes = ["Collect read-only family/version metadata exposed by the tag"]
            }

            if let hist = card.details["Historical Bytes"], hist != "—", !hist.isEmpty {
                evidence.append(.init(
                    source: "ISO 14443 activation",
                    observation: "Historical bytes: \(hist)",
                    interpretation: "Activation metadata is available as additional fingerprinting evidence.",
                    weight: 0.10
                ))
            }
        }

        if tech.contains("7816") {
            family = "ISO 7816 Smart Card"
            baseConfidence = max(baseConfidence, 0.80)

            if let aid = card.details["Initial AID"], aid != "—", !aid.isEmpty {
                evidence.append(.init(
                    source: "ISO 7816",
                    observation: "Initial selected AID: \(aid)",
                    interpretation: "An application identifier was selected during activation.",
                    weight: 0.20
                ))

                if normalizeHex(aid) == "D2760000850101" {
                    variant = "NFC Forum Type 4 / NDEF application"
                    baseConfidence = 0.96
                    probes = [
                        "Read CC file",
                        "Read NDEF file according to the Type 4 mapping"
                    ]
                } else {
                    probes = [
                        "Inspect only explicitly configured/public application identifiers",
                        "Collect FCI/response metadata from permitted SELECT operations"
                    ]
                }
            }
        }

        if tech.contains("15693") {
            family = "ISO 15693 / NFC-V"
            variant = "Vicinity card"
            baseConfidence = 0.90
            probes = [
                "Get System Information",
                "Inspect block size/count",
                "Read capability container if NDEF is supported"
            ]

            if let code = card.details["Manufacturer Code"] {
                let manufacturer = manufacturerName(for: code)
                evidence.append(.init(
                    source: "ISO 15693",
                    observation: "Manufacturer code: \(code)",
                    interpretation: manufacturer.map { "Assigned manufacturer: \($0)." } ?? "Manufacturer code is visible for family fingerprinting.",
                    weight: 0.18
                ))
                if let manufacturer {
                    variant = "\(manufacturer) ISO 15693"
                    baseConfidence = 0.93
                }
            }
        }

        if tech.contains("felica") {
            family = "FeliCa / NFC-F"
            variant = "FeliCa"
            baseConfidence = 0.92
            probes = [
                "Request System Code",
                "Request Service",
                "Inspect NDEF service only when the configured system permits it"
            ]

            if let system = card.details["System Code"] {
                evidence.append(.init(
                    source: "FeliCa",
                    observation: "System Code: \(system)",
                    interpretation: normalizeHex(system) == "12FC"
                        ? "0x12FC is the NFC Forum Type 3 Tag / NDEF system code."
                        : "The system code identifies the active FeliCa system.",
                    weight: 0.22
                ))
                if normalizeHex(system) == "12FC" {
                    variant = "FeliCa NFC Forum Type 3 / NDEF"
                    baseConfidence = 0.97
                }
            }
        }

        if let ndef = card.ndef {
            evidence.append(.init(
                source: "NDEF probe",
                observation: "Access: \(ndef.access.rawValue), capacity: \(ndef.capacity), records: \(ndef.records.count)",
                interpretation: ndef.access == .unsupported
                    ? "No NDEF mapping was exposed by this scan."
                    : "The tag exposes an NFC Forum NDEF mapping.",
                weight: ndef.access == .unsupported ? 0.03 : 0.12
            ))
        }

        if let uid = card.uidHex, !uid.isEmpty {
            evidence.append(.init(
                source: "Activation",
                observation: "Identifier length: \(uid.count / 2) bytes",
                interpretation: "Identifier length is supporting evidence only; NFCCard never identifies a secure product from UID alone.",
                weight: 0.03
            ))
        }

        let evidenceBoost = min(evidence.map(\.weight).reduce(0, +) * 0.15, 0.05)
        let confidence = min(baseConfidence + evidenceBoost, 0.99)

        if probes.isEmpty {
            probes = ["Collect additional standards-compliant read-only metadata for this transport"]
        }

        return ProtocolAtlasReport(
            family: family,
            variant: variant,
            confidence: confidence,
            evidence: evidence,
            nextReadOnlyProbes: probes,
            limitations: limitations
        )
    }

    private static func normalizeHex(_ value: String) -> String {
        value
            .uppercased()
            .replacingOccurrences(of: "0X", with: "")
            .filter { $0.isHexDigit }
    }

    private static func manufacturerName(for code: String) -> String? {
        guard let value = UInt8(normalizeHex(code), radix: 16) else { return nil }

        switch value {
        case 0x04: return "NXP Semiconductors"
        case 0x02: return "STMicroelectronics"
        case 0x07: return "Texas Instruments"
        default: return nil
        }
    }
}

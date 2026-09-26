import Foundation

struct NDEFRecordData: Equatable {
    let format: UInt8
    let type: Data
    let identifier: Data
    let payload: Data

    var encodedLength: Int {
        3 + (payload.count > 255 ? 3 : 0) + (identifier.isEmpty ? 0 : 1)
        + type.count + identifier.count + payload.count
    }

    var displayValue: String {
        if format == 1, type == Data([0x54]), let status = payload.first {
            let start = 1 + Int(status & 0x3f)
            if start <= payload.count,
               let text = String(data: payload.dropFirst(start), encoding: status & 0x80 == 0 ? .utf8 : .utf16) {
                return text
            }
        }
        if format == 1, type == Data([0x55]), let code = payload.first {
            let prefixes = ["", "http://www.", "https://www.", "http://", "https://"]
            if Int(code) < prefixes.count, let value = String(data: payload.dropFirst(), encoding: .utf8) {
                return prefixes[Int(code)] + value
            }
        }
        return payload.map { String(format: "%02X", $0) }.joined()
    }
}

struct NDEFReadResult: Equatable {
    let identity: String
    let technology: String
    let access: NDEFMetadata.Access
    let capacity: Int
    /// nil means unsupported/unread, not an empty NDEF message.
    let records: [NDEFRecordData]?
    let inspectedAt: Date
    /// Public metadata from this physical scan; not a dump of protected memory.
    var cardProfile: NFCCardProfile? = nil

    var cardSnapshot: NFCCardProfile {
        var card = cardProfile ?? NFCCardProfile(technology: technology, uidHex: identity.isEmpty ? nil : identity)
        card.scannedAt = inspectedAt
        card.ndef = NDEFMetadata(access: access, capacity: capacity, records: (records ?? []).map {
            NDEFRecordSummary(typeNameFormat: String($0.format), type: $0.type.hexString,
                              identifierHex: $0.identifier.hexString,
                              payloadPreview: String($0.displayValue.prefix(512)), payloadLength: $0.payload.count)
        })
        card.matchedModules = CardModuleRegistry.matches(for: card)
        card.capabilities = CapabilityMapService.capabilities(for: card)
        card.privacyInsights = CardPrivacyAnalyzer.analyze(card)
        card.genome = CardGenomeService.fingerprint(card)
        return card
    }

    var canPrepareWrite: Bool {
        access == .readWrite && capacity > 0 && !identity.isEmpty && records != nil
    }
}

struct NDEFWritePlan: Equatable {
    let before: NDEFReadResult
    let replacement: [NDEFRecordData]
}

enum NDEFRequest {
    case read
    case write(NDEFWritePlan)
    var isWrite: Bool { if case .write = self { return true }; return false }
}

enum NDEFWritePolicy {
    enum DraftKind: String, CaseIterable { case text = "Text", url = "Web URL" }
    static let maximumDraftBytes = 4096
    static let maximumReadBytes = 65_536
    static let confirmationLifetime: TimeInterval = 120

    struct Failure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    static func draft(_ value: String, kind: DraftKind) throws -> [NDEFRecordData] {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure(reason: "Enter text or a web URL first.")
        }
        guard value.utf8.count <= maximumDraftBytes else {
            throw Failure(reason: "The draft exceeds the 4096-byte input limit.")
        }
        let type: Data
        let payload: Data
        switch kind {
        case .text:
            type = Data([0x54])
            payload = Data([0x02, 0x65, 0x6e]) + Data(value.utf8) // UTF-8, language en
        case .url:
            guard !value.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0) }),
                  let url = URLComponents(string: value),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil, url.url != nil else {
                throw Failure(reason: "Enter a complete http:// or https:// URL without spaces or embedded credentials.")
            }
            type = Data([0x55])
            payload = Data([0]) + Data(value.utf8) // No URI prefix compression
        }
        return [NDEFRecordData(format: 1, type: type, identifier: Data(), payload: payload)]
    }

    static func byteCount(_ records: [NDEFRecordData]) -> Int { records.reduce(0) { $0 + $1.encodedLength } }

    static func validateRead(_ records: [NDEFRecordData]) throws {
        guard records.count <= 128, byteCount(records) <= maximumReadBytes else {
            throw Failure(reason: "NDEF content exceeds the safe read limit. Nothing was written.")
        }
    }

    static func validate(_ plan: NDEFWritePlan, now: Date = .now) throws {
        guard plan.before.canPrepareWrite else {
            throw Failure(reason: "Read a writable NDEF tag first. Unsupported or read-only cards cannot be written.")
        }
        let age = now.timeIntervalSince(plan.before.inspectedAt)
        guard age >= 0, age <= confirmationLifetime else {
            throw Failure(reason: "The inspection expired. Read the tag again before confirming a write.")
        }
        guard plan.replacement.count == 1, let record = plan.replacement.first,
              record.format == 1, record.identifier.isEmpty,
              record.type == Data([0x54]) || record.type == Data([0x55]),
              !record.payload.isEmpty, record.payload.count <= maximumDraftBytes + 3 else {
            throw Failure(reason: "Only a single text or web URL record can be written.")
        }
        guard byteCount(plan.replacement) <= plan.before.capacity else {
            throw Failure(reason: "The new NDEF message is larger than the tag's capacity.")
        }
        let canonical = try draft(record.displayValue, kind: record.type == Data([0x54]) ? .text : .url)
        guard canonical == plan.replacement else {
            throw Failure(reason: "The replacement is not a valid UTF-8 text or HTTP(S) URL record.")
        }
    }

    static func validateTarget(_ current: NDEFReadResult, plan: NDEFWritePlan, now: Date = .now) throws {
        try validate(plan, now: now)
        guard current.identity == plan.before.identity, current.technology == plan.before.technology else {
            throw Failure(reason: "A different tag was detected. Nothing was written. Present the inspected tag.")
        }
        guard current.canPrepareWrite, byteCount(plan.replacement) <= current.capacity else {
            throw Failure(reason: "The tag is no longer writable or has insufficient capacity. Nothing was written.")
        }
        guard current.records == plan.before.records else {
            throw Failure(reason: "The tag content changed after inspection. Nothing was written. Read it again.")
        }
    }
}

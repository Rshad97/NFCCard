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

    var usedBytes: Int {
        records?.reduce(0) { $0 + $1.encodedLength } ?? 0
    }

    var remainingCapacity: Int? {
        guard access != .unsupported else { return nil }
        return max(0, capacity - usedBytes)
    }

    var writeStatusText: String {
        switch access {
        case .readWrite:
            return canPrepareWrite ? "Writable" : "Writable NDEF reported — re-read required"
        case .readOnly:
            return "Read-only"
        case .unsupported:
            return "NDEF unsupported"
        case .unknown:
            return "Write capability unknown"
        }
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
    enum DraftKind: String, CaseIterable {
        case text = "Text"
        case url = "Web URL"
        case email = "Email"
        case phone = "Phone"

        var placeholder: String {
            switch self {
            case .text: return "Text to write"
            case .url: return "https://example.com"
            case .email: return "name@example.com"
            case .phone: return "+966 50 123 4567"
            }
        }
    }
    static let maximumDraftBytes = 4096
    static let maximumReadBytes = 65_536
    static let confirmationLifetime: TimeInterval = 120

    struct Failure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    static func draft(_ rawValue: String, kind: DraftKind) throws -> [NDEFRecordData] {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw Failure(reason: "Enter content first.")
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
            guard !value.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
            }),
            let url = URLComponents(string: value),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            let host = url.host, !host.isEmpty,
            url.user == nil, url.password == nil, url.url != nil else {
                throw Failure(reason: "Enter a complete http:// or https:// URL without spaces or embedded credentials.")
            }
            type = Data([0x55])
            payload = Data([0]) + Data(value.utf8)

        case .email:
            guard !value.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
            }) else {
                throw Failure(reason: "Enter one email address without spaces.")
            }
            let parts = value.split(separator: "@", omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty, parts[1].contains(".") else {
                throw Failure(reason: "Enter a valid email address.")
            }
            type = Data([0x55])
            payload = Data([0]) + Data("mailto:\(value)".utf8)

        case .phone:
            let allowed = CharacterSet(charactersIn: "+0123456789 -()")
            guard !value.unicodeScalars.contains(where: { !allowed.contains($0) }) else {
                throw Failure(reason: "Enter a phone number using digits and common separators only.")
            }
            let hasPlus = value.trimmingCharacters(in: .whitespaces).hasPrefix("+")
            let digits = value.filter(\.isNumber)
            guard (3...20).contains(digits.count) else {
                throw Failure(reason: "Enter a valid phone number.")
            }
            let canonical = (hasPlus ? "+" : "") + digits
            type = Data([0x55])
            payload = Data([0]) + Data("tel:\(canonical)".utf8)
        }

        return [NDEFRecordData(format: 1, type: type, identifier: Data(), payload: payload)]
    }

    private static func canonicalDraft(for record: NDEFRecordData) throws -> [NDEFRecordData] {
        guard record.format == 1, record.identifier.isEmpty else {
            throw Failure(reason: "Unsupported NDEF record.")
        }

        if record.type == Data([0x54]) {
            return try draft(record.displayValue, kind: .text)
        }

        guard record.type == Data([0x55]) else {
            throw Failure(reason: "Unsupported NDEF record.")
        }

        let value = record.displayValue
        if value.lowercased().hasPrefix("mailto:") {
            return try draft(String(value.dropFirst(7)), kind: .email)
        }
        if value.lowercased().hasPrefix("tel:") {
            return try draft(String(value.dropFirst(4)), kind: .phone)
        }
        return try draft(value, kind: .url)
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
              !record.payload.isEmpty, record.payload.count <= maximumDraftBytes + 16 else {
            throw Failure(reason: "Only one supported Text, Web URL, Email or Phone NDEF record can be written.")
        }
        guard byteCount(plan.replacement) <= plan.before.capacity else {
            throw Failure(reason: "The new NDEF message is larger than the tag's capacity.")
        }
        let canonical = try canonicalDraft(for: record)
        guard canonical == plan.replacement else {
            throw Failure(reason: "The replacement is not a valid supported NDEF record.")
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

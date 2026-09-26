import Foundation

enum DESFireVersionParser {
    static func parse(payload: Data, statusWords: [UInt16], observedUIDHex: String?) -> NFCReadOnlyProbeResult {
        let statuses = statusWords.map { String(format: "%04X", $0) }
        let continuationOK = statusWords.dropLast().allSatisfy { $0 == 0x91AF }
        let finalOK = statusWords.last == 0x9100
        let recognized = payload.count >= 28 && continuationOK && finalOK

        var details: [String: String] = [:]

        if payload.count >= 7 {
            let hardware = Array(payload[0..<7])
            details["Vendor"] = vendorDescription(hardware[0])
            details["Hardware Type"] = hexByte(hardware[1])
            details["Hardware Subtype"] = hexByte(hardware[2])
            details["Hardware Version"] = "\(hardware[3]).\(hardware[4])"
            details["Storage"] = storageDescription(hardware[5])
            details["Hardware Protocol"] = hexByte(hardware[6])
        }

        if payload.count >= 14 {
            let software = Array(payload[7..<14])
            details["Software Vendor"] = vendorDescription(software[0])
            details["Software Type"] = hexByte(software[1])
            details["Software Subtype"] = hexByte(software[2])
            details["Software Version"] = "\(software[3]).\(software[4])"
            details["Software Storage"] = storageDescription(software[5])
            details["Software Protocol"] = hexByte(software[6])
        }

        if payload.count >= 28 {
            let uid = Data(payload[14..<21]).hexString
            let batch = Data(payload[21..<26]).hexString
            details["Version UID"] = uid
            details["Batch Number"] = batch
            details["Production Week Code"] = hexByte(payload[26])
            details["Production Year Code"] = hexByte(payload[27])

            if let observedUIDHex, !observedUIDHex.isEmpty {
                details["UID Match"] = observedUIDHex.caseInsensitiveCompare(uid) == .orderedSame ? "Yes" : "No"
            }
        }

        return NFCReadOnlyProbeResult(
            kind: .desfireGetVersion,
            observedUIDHex: observedUIDHex,
            recognized: recognized,
            summary: recognized
                ? "DESFire-compatible GetVersion response"
                : "DESFire GetVersion not confirmed",
            statusWords: statuses,
            rawResponseHex: payload.hexString,
            details: details
        )
    }

    private static func vendorDescription(_ value: UInt8) -> String {
        value == 0x04 ? "NXP (0x04)" : "0x" + hexByte(value)
    }

    private static func hexByte(_ value: UInt8) -> String {
        String(format: "%02X", value)
    }

    private static func storageDescription(_ code: UInt8) -> String {
        let exponent = Int(code >> 1)
        guard exponent >= 8 && exponent <= 24 else {
            return "Code 0x" + hexByte(code)
        }

        let lower = 1 << exponent
        if code & 0x01 == 0 {
            return "\(lower) bytes (code 0x\(hexByte(code)))"
        }

        let upper = 1 << (exponent + 1)
        return "\(lower)–\(upper) bytes (code 0x\(hexByte(code)))"
    }
}

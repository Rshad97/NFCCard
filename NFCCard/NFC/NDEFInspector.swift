import Foundation
import CoreNFC

enum NDEFInspector {
    static func inspect(tag: NFCTag, completion: @escaping (NDEFMetadata) -> Void) {
        switch tag {
        case .miFare(let value): inspectNDEFTag(value, completion: completion)
        case .iso7816(let value): inspectNDEFTag(value, completion: completion)
        case .iso15693(let value): inspectNDEFTag(value, completion: completion)
        case .feliCa(let value): inspectNDEFTag(value, completion: completion)
        @unknown default: completion(NDEFMetadata(access: .unknown, capacity: 0, records: []))
        }
    }

    private static func inspectNDEFTag(_ tag: any NFCNDEFTag, completion: @escaping (NDEFMetadata) -> Void) {
        tag.queryNDEFStatus { status, capacity, error in
            guard error == nil else {
                completion(NDEFMetadata(access: .unknown, capacity: 0, records: []))
                return
            }

            let access: NDEFMetadata.Access
            switch status {
            case .notSupported: access = .unsupported
            case .readOnly: access = .readOnly
            case .readWrite: access = .readWrite
            @unknown default: access = .unknown
            }

            guard status != .notSupported else {
                completion(NDEFMetadata(access: access, capacity: capacity, records: []))
                return
            }

            tag.readNDEF { message, _ in
                let records = message?.records.map { record in
                    let type = String(data: record.type, encoding: .utf8) ?? record.type.hexString
                    let previewData = record.payload.prefix(64)
                    let preview = String(data: previewData, encoding: .utf8) ?? Data(previewData).hexString
                    return NDEFRecordSummary(
                        typeNameFormat: String(describing: record.typeNameFormat),
                        type: type,
                        identifierHex: record.identifier.hexString,
                        payloadPreview: preview,
                        payloadLength: record.payload.count
                    )
                } ?? []

                completion(NDEFMetadata(access: access, capacity: capacity, records: records))
            }
        }
    }
}

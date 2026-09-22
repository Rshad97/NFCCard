import Foundation
import CoreNFC

enum NDEFInspector {
    private static let operationTimeout: TimeInterval = 4

    static func inspect(tag: NFCTag, completion: @escaping (NDEFMetadata) -> Void) {
        switch tag {
        case .miFare(let value): inspectNDEFTag(value, completion: completion)
        case .iso7816(let value): inspectNDEFTag(value, completion: completion)
        case .iso15693(let value): inspectNDEFTag(value, completion: completion)
        case .feliCa(let value): inspectNDEFTag(value, completion: completion)
        @unknown default:
            completion(NDEFMetadata(access: .unknown, capacity: 0, records: []))
        }
    }

    private static func inspectNDEFTag(_ tag: any NFCNDEFTag, completion: @escaping (NDEFMetadata) -> Void) {
        let finish = OneShot(completion)

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + operationTimeout) {
            finish.call(NDEFMetadata(access: .unknown, capacity: 0, records: []))
        }

        tag.queryNDEFStatus { status, capacity, error in
            guard error == nil else {
                finish.call(NDEFMetadata(access: .unknown, capacity: 0, records: []))
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
                finish.call(NDEFMetadata(access: access, capacity: capacity, records: []))
                return
            }

            tag.readNDEF { message, error in
                guard error == nil else {
                    finish.call(NDEFMetadata(access: access, capacity: capacity, records: []))
                    return
                }

                let records: [NDEFRecordSummary]
                if let message {
                    records = message.records.map { record -> NDEFRecordSummary in
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
                    }
                } else {
                    records = []
                }

                finish.call(NDEFMetadata(access: access, capacity: capacity, records: records))
            }
        }
    }
}

private final class OneShot<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((Value) -> Void)?

    init(_ completion: @escaping (Value) -> Void) {
        self.completion = completion
    }

    func call(_ value: Value) {
        lock.lock()
        let callback = completion
        completion = nil
        lock.unlock()
        callback?(value)
    }
}

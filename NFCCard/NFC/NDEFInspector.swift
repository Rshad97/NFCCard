import Foundation
import CoreNFC

/// Query, timeout, cancellation and result handling share the reader queue.
/// A late query response cannot initiate readNDEF after the scan has ended.
final class NDEFInspection {
    private(set) var isFinished = false
    private var completion: ((NDEFMetadata) -> Void)?
    private var timeout: DispatchWorkItem?

    init(queue: DispatchQueue, completion: @escaping (NDEFMetadata) -> Void) {
        self.completion = completion
        let work = DispatchWorkItem { [weak self] in self?.finish(NDEFMetadata()) }
        timeout = work
        queue.asyncAfter(deadline: .now() + 4, execute: work)
    }

    func cancel() {
        isFinished = true
        completion = nil
        timeout?.cancel()
        timeout = nil
    }

    func finish(_ metadata: NDEFMetadata) {
        guard !isFinished else { return }
        let callback = completion
        cancel()
        callback?(metadata)
    }
}

enum NDEFInspector {
    static func inspect(tag: NFCTag, queue: DispatchQueue,
                        completion: @escaping (NDEFMetadata) -> Void) -> NDEFInspection {
        let operation = NDEFInspection(queue: queue, completion: completion)
        switch tag {
        case .miFare(let value): inspect(value, queue: queue, operation: operation)
        case .iso7816(let value): inspect(value, queue: queue, operation: operation)
        case .iso15693(let value): inspect(value, queue: queue, operation: operation)
        case .feliCa(let value): inspect(value, queue: queue, operation: operation)
        @unknown default: operation.finish(NDEFMetadata())
        }
        return operation
    }

    private static func inspect(_ tag: any NFCNDEFTag, queue: DispatchQueue, operation: NDEFInspection) {
        tag.queryNDEFStatus { status, capacity, error in
            queue.async {
                guard !operation.isFinished else { return }
                guard error == nil else { operation.finish(NDEFMetadata()); return }
                let access: NDEFMetadata.Access
                switch status {
                case .notSupported: access = .unsupported
                case .readOnly: access = .readOnly
                case .readWrite: access = .readWrite
                @unknown default: access = .unknown
                }
                let metadata = NDEFMetadata(access: access, capacity: max(0, capacity), records: [])
                guard status == .readOnly || status == .readWrite else { operation.finish(metadata); return }
                tag.readNDEF { message, error in
                    queue.async {
                        guard !operation.isFinished else { return }
                        var result = metadata
                        if error == nil, let message {
                            result.records = message.records.map { record in
                                let preview = Data(record.payload.prefix(64))
                                return NDEFRecordSummary(
                                    typeNameFormat: String(describing: record.typeNameFormat),
                                    type: String(data: record.type, encoding: .utf8) ?? record.type.hexString,
                                    identifierHex: record.identifier.hexString,
                                    payloadPreview: String(data: preview, encoding: .utf8) ?? preview.hexString,
                                    payloadLength: record.payload.count)
                            }
                        }
                        operation.finish(result)
                    }
                }
            }
        }
    }
}

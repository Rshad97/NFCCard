import Foundation
import CoreNFC

final class CoreNDEFTag: NDEFTagAccessing {
    let identity: String
    let technology: String
    private let tag: any NFCNDEFTag

    init?(tag: NFCTag, card: NFCCardProfile) {
        identity = card.uidHex ?? ""
        technology = card.technology
        switch tag {
        case .miFare(let value): self.tag = value
        case .iso7816(let value): self.tag = value
        case .iso15693(let value): self.tag = value
        case .feliCa(let value): self.tag = value
        @unknown default: return nil
        }
    }

    func query(_ completion: @escaping (Result<NDEFTagStatus, Error>) -> Void) {
        tag.queryNDEFStatus { status, capacity, error in
            if let error { completion(.failure(error)); return }
            let access: NDEFMetadata.Access
            switch status {
            case .notSupported: access = .unsupported
            case .readOnly: access = .readOnly
            case .readWrite: access = .readWrite
            @unknown default: access = .unknown
            }
            completion(.success(NDEFTagStatus(access: access, capacity: capacity)))
        }
    }

    func read(_ completion: @escaping (Result<[NDEFRecordData], Error>) -> Void) {
        tag.readNDEF { message, error in
            if let error {
                // Only the explicit empty-message error means a blank NDEF tag.
                // All transport/authentication failures remain failures.
                if let nfc = error as? NFCReaderError, nfc.code == .ndefReaderSessionErrorZeroLengthMessage {
                    completion(.success([]))
                } else { completion(.failure(error)) }
                return
            }
            guard let message else {
                completion(.failure(NDEFWritePolicy.Failure(reason: "No NDEF message returned.")))
                return
            }
            completion(.success(message.records.map {
                NDEFRecordData(format: $0.typeNameFormat.rawValue, type: $0.type,
                               identifier: $0.identifier, payload: $0.payload)
            }))
        }
    }

    func write(_ records: [NDEFRecordData], completion: @escaping (Error?) -> Void) {
        var payloads: [NFCNDEFPayload] = []
        for record in records {
            guard let format = NFCTypeNameFormat(rawValue: record.format) else {
                completion(NDEFWritePolicy.Failure(reason: "Invalid NDEF type.")); return
            }
            payloads.append(NFCNDEFPayload(format: format, type: record.type,
                                           identifier: record.identifier, payload: record.payload))
        }
        let message = NFCNDEFMessage(records: payloads)
        guard message.length == NDEFWritePolicy.byteCount(records) else {
            completion(NDEFWritePolicy.Failure(reason: "NDEF encoded length mismatch.")); return
        }
        tag.writeNDEF(message, completionHandler: completion)
    }
}

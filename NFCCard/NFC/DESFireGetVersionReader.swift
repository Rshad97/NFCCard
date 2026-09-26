import Foundation
import CoreNFC

enum DESFireGetVersionReader {
    private static let maximumFrames = 4

    static func run(
        tag: any NFCISO7816Tag,
        observedUIDHex: String?,
        queue: DispatchQueue,
        completion: @escaping (Result<NFCReadOnlyProbeResult, Error>) -> Void
    ) {
        send(
            instruction: 0x60,
            tag: tag,
            observedUIDHex: observedUIDHex,
            queue: queue,
            accumulated: Data(),
            statusWords: [],
            frame: 0,
            completion: completion
        )
    }

    private static func send(
        instruction: UInt8,
        tag: any NFCISO7816Tag,
        observedUIDHex: String?,
        queue: DispatchQueue,
        accumulated: Data,
        statusWords: [UInt16],
        frame: Int,
        completion: @escaping (Result<NFCReadOnlyProbeResult, Error>) -> Void
    ) {
        let apdu = NFCISO7816APDU(
            instructionClass: 0x90,
            instructionCode: instruction,
            p1Parameter: 0x00,
            p2Parameter: 0x00,
            data: Data(),
            expectedResponseLength: 0
        )

        tag.sendCommand(apdu: apdu) { data, sw1, sw2, error in
            queue.async {
                if let error {
                    completion(.failure(error))
                    return
                }

                var payload = accumulated
                payload.append(data)

                var statuses = statusWords
                let status = (UInt16(sw1) << 8) | UInt16(sw2)
                statuses.append(status)

                if status == 0x91AF {
                    guard frame + 1 < maximumFrames else {
                        completion(.failure(ProbeFailure("DESFire GetVersion returned too many continuation frames.")))
                        return
                    }

                    send(
                        instruction: 0xAF,
                        tag: tag,
                        observedUIDHex: observedUIDHex,
                        queue: queue,
                        accumulated: payload,
                        statusWords: statuses,
                        frame: frame + 1,
                        completion: completion
                    )
                    return
                }

                completion(.success(
                    DESFireVersionParser.parse(
                        payload: payload,
                        statusWords: statuses,
                        observedUIDHex: observedUIDHex
                    )
                ))
            }
        }
    }

    private struct ProbeFailure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

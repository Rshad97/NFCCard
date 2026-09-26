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
        readVersion(
            tag: tag,
            observedUIDHex: observedUIDHex,
            queue: queue,
            accumulated: Data(),
            statusWords: [],
            frame: 0,
            allowPICCSelectionFallback: true,
            completion: completion
        )
    }

    private static func readVersion(
        tag: any NFCISO7816Tag,
        observedUIDHex: String?,
        queue: DispatchQueue,
        accumulated: Data,
        statusWords: [UInt16],
        frame: Int,
        allowPICCSelectionFallback: Bool,
        completion: @escaping (Result<NFCReadOnlyProbeResult, Error>) -> Void
    ) {
        send(
            instruction: frame == 0 ? 0x60 : 0xAF,
            data: Data(),
            tag: tag,
            queue: queue
        ) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let response):
                var payload = accumulated
                payload.append(response.data)

                var statuses = statusWords
                statuses.append(response.status)

                if response.status == 0x91AF {
                    guard frame + 1 < maximumFrames else {
                        completion(.failure(ProbeFailure("DESFire GetVersion returned too many continuation frames.")))
                        return
                    }

                    readVersion(
                        tag: tag,
                        observedUIDHex: observedUIDHex,
                        queue: queue,
                        accumulated: payload,
                        statusWords: statuses,
                        frame: frame + 1,
                        allowPICCSelectionFallback: false,
                        completion: completion
                    )
                    return
                }

                // Some ISO 7816 sessions begin with an application already selected.
                // A 910B response has been observed when native DESFire commands are
                // rejected in that state. Select the DESFire PICC master application
                // (AID 000000) once, then retry GetVersion. This only changes the
                // volatile selection state for the current RF session; it writes no
                // card memory and performs no authentication.
                if response.status == 0x910B, frame == 0, allowPICCSelectionFallback {
                    selectPICC(
                        tag: tag,
                        queue: queue
                    ) { selectResult in
                        switch selectResult {
                        case .failure(let error):
                            completion(.failure(error))

                        case .success(let selectResponse):
                            guard selectResponse.status == 0x9100 else {
                                let parsed = DESFireVersionParser.parse(
                                    payload: payload,
                                    statusWords: statuses + [selectResponse.status],
                                    observedUIDHex: observedUIDHex
                                )
                                completion(.success(
                                    NFCReadOnlyProbeResult(
                                        kind: parsed.kind,
                                        observedUIDHex: parsed.observedUIDHex,
                                        recognized: false,
                                        summary: "DESFire GetVersion not confirmed; PICC selection fallback was rejected",
                                        statusWords: parsed.statusWords,
                                        rawResponseHex: parsed.rawResponseHex,
                                        details: parsed.details.merging([
                                            "Fallback": "Select PICC (AID 000000)",
                                            "Fallback Status": String(format: "%04X", selectResponse.status)
                                        ]) { current, _ in current }
                                    )
                                ))
                                return
                            }

                            readVersion(
                                tag: tag,
                                observedUIDHex: observedUIDHex,
                                queue: queue,
                                accumulated: Data(),
                                statusWords: [],
                                frame: 0,
                                allowPICCSelectionFallback: false
                            ) { retryResult in
                                switch retryResult {
                                case .failure(let error):
                                    completion(.failure(error))
                                case .success(let retry):
                                    var details = retry.details
                                    details["Fallback"] = "Selected PICC master AID 000000 before retry"
                                    details["Fallback Status"] = "9100"
                                    completion(.success(
                                        NFCReadOnlyProbeResult(
                                            kind: retry.kind,
                                            observedUIDHex: retry.observedUIDHex,
                                            recognized: retry.recognized,
                                            summary: retry.recognized
                                                ? "DESFire-compatible GetVersion response after PICC selection"
                                                : retry.summary,
                                            statusWords: retry.statusWords,
                                            rawResponseHex: retry.rawResponseHex,
                                            details: details
                                        )
                                    ))
                                }
                            }
                        }
                    }
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

    private static func selectPICC(
        tag: any NFCISO7816Tag,
        queue: DispatchQueue,
        completion: @escaping (Result<Response, Error>) -> Void
    ) {
        send(
            instruction: 0x5A,
            data: Data([0x00, 0x00, 0x00]),
            tag: tag,
            queue: queue,
            completion: completion
        )
    }

    private static func send(
        instruction: UInt8,
        data: Data,
        tag: any NFCISO7816Tag,
        queue: DispatchQueue,
        completion: @escaping (Result<Response, Error>) -> Void
    ) {
        let apdu = NFCISO7816APDU(
            instructionClass: 0x90,
            instructionCode: instruction,
            p1Parameter: 0x00,
            p2Parameter: 0x00,
            data: data,
            // Core NFC requires Le to be 1...65536 or -1. For DESFire
            // wrapped-native commands, 256 encodes a short Le of 0x00.
            expectedResponseLength: 256
        )

        tag.sendCommand(apdu: apdu) { responseData, sw1, sw2, error in
            queue.async {
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(
                    Response(
                        data: responseData,
                        status: (UInt16(sw1) << 8) | UInt16(sw2)
                    )
                ))
            }
        }
    }

    private struct Response {
        let data: Data
        let status: UInt16
    }

    private struct ProbeFailure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}

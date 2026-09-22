import Foundation
import CoreNFC

@MainActor
final class NFCScanner: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastCard: NFCCardProfile?
    @Published var log: [String] = []
    @Published var errorMessage: String?

    weak var library: CardLibraryStore?
    private var session: NFCTagReaderSession?

    func startScan() {
        guard NFCReaderSession.readingAvailable else {
            errorMessage = "NFC reading is not available on this device."
            return
        }

        guard let newSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: nil
        ) else {
            errorMessage = "Unable to create an NFC reader session."
            return
        }

        newSession.alertMessage = "Hold the top of your iPhone near the NFC card."
        session = newSession
        isScanning = true
        appendLog("Starting NFC discovery")
        newSession.begin()
    }

    func clearLog() {
        log.removeAll()
    }

    private func appendLog(_ message: String) {
        log.append("\(ISO8601DateFormatter().string(from: .now))  \(message)")
    }

    private func baseProfile(for tag: NFCTag) -> NFCCardProfile {
        switch tag {
        case .miFare(let mifare):
            return NFCCardProfile(
                technology: "ISO 14443 / MIFARE",
                uidHex: mifare.identifier.hexString,
                subtype: String(describing: mifare.mifareFamily),
                details: [
                    "Historical Bytes": mifare.historicalBytes?.hexString ?? "—",
                    "Family": String(describing: mifare.mifareFamily)
                ]
            )

        case .iso7816(let iso7816):
            return NFCCardProfile(
                technology: "ISO 7816",
                uidHex: iso7816.identifier.hexString,
                subtype: iso7816.initialSelectedAID,
                details: [
                    "Historical Bytes": iso7816.historicalBytes?.hexString ?? "—",
                    "Application Data": iso7816.applicationData?.hexString ?? "—",
                    "Initial AID": iso7816.initialSelectedAID ?? "—"
                ]
            )

        case .iso15693(let iso15693):
            return NFCCardProfile(
                technology: "ISO 15693",
                uidHex: iso15693.identifier.hexString,
                details: [
                    "Manufacturer Code": String(format: "0x%02X", iso15693.icManufacturerCode),
                    "Serial Number": iso15693.icSerialNumber.hexString
                ]
            )

        case .feliCa(let felica):
            return NFCCardProfile(
                technology: "FeliCa / ISO 18092",
                uidHex: felica.currentIDm.hexString,
                details: [
                    "System Code": felica.currentSystemCode.hexString
                ]
            )

        @unknown default:
            return NFCCardProfile(technology: "Unknown NFC")
        }
    }

    private func finalize(_ card: NFCCardProfile, session: NFCTagReaderSession) {
        var enriched = card
        enriched.matchedModules = CardModuleRegistry.matches(for: enriched)
        enriched.capabilities = CapabilityMapService.capabilities(for: enriched)
        enriched.privacyInsights = CardPrivacyAnalyzer.analyze(enriched)
        enriched.genome = CardGenomeService.fingerprint(enriched)

        lastCard = enriched
        library?.save(enriched)

        appendLog("Detected \(enriched.technology) UID=\(enriched.uidHex ?? "—")")
        appendLog("Card Genome \(String((enriched.genome ?? "").prefix(16)).uppercased())")
        if let ndef = enriched.ndef {
            appendLog("NDEF \(ndef.access.rawValue), capacity=\(ndef.capacity), records=\(ndef.records.count)")
        }
        appendLog("Matched modules: \(enriched.matchedModules.joined(separator: ", "))")

        session.alertMessage = "Card analyzed"
        session.invalidate()
    }
}

extension NFCScanner: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Task { @MainActor in
            self.appendLog("Reader session active")
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            let readerError = error as? NFCReaderError
            if readerError?.code != .readerSessionInvalidationErrorUserCanceled {
                self.appendLog("Session ended: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let tag = tags.first else { return }

        if tags.count > 1 {
            session.alertMessage = "More than one NFC card detected. Present one card only."
            session.restartPolling()
            return
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            Task { @MainActor in
                self.appendLog("Connected to tag; collecting public protocol metadata")
                var card = self.baseProfile(for: tag)

                NDEFInspector.inspect(tag: tag) { metadata in
                    Task { @MainActor in
                        card.ndef = metadata
                        self.finalize(card, session: session)
                    }
                }
            }
        }
    }
}

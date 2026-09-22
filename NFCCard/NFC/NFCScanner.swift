import Foundation
import CoreNFC

@MainActor
final class NFCScanner: NSObject, ObservableObject {
    @Published private(set) var isScanning = false
    @Published private(set) var statusMessage = "Ready"
    @Published var lastCard: NFCCardProfile?
    @Published var log: [String] = []
    @Published var errorMessage: String?

    weak var library: CardLibraryStore?

    private let readerQueue = DispatchQueue(label: "com.rashad.nfccard.reader", qos: .userInitiated)
    private var session: NFCTagReaderSession?
    private var activationWatchdog: Task<Void, Never>?
    private var sessionWatchdog: Task<Void, Never>?
    private var didCompleteCurrentScan = false

    func startScan() {
        guard !isScanning else {
            appendLog("Scan request ignored because a session is already active")
            return
        }

        guard NFCReaderSession.readingAvailable else {
            errorMessage = "NFC reading is not available on this device."
            statusMessage = "NFC unavailable"
            return
        }

        errorMessage = nil
        didCompleteCurrentScan = false
        statusMessage = "Starting NFC reader…"

        guard let newSession = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: readerQueue
        ) else {
            errorMessage = "Unable to create an NFC reader session."
            statusMessage = "Could not start"
            return
        }

        newSession.alertMessage = "Hold the top of your iPhone near the NFC card."
        session = newSession
        isScanning = true
        appendLog("Starting NFC discovery")
        scheduleActivationWatchdog()
        newSession.begin()
    }

    func cancelScan() {
        guard let session else { return }
        appendLog("User requested scan cancellation")
        statusMessage = "Canceling…"
        session.invalidate()
    }

    func clearLog() {
        log.removeAll()
    }

    private func appendLog(_ message: String) {
        log.append("\(ISO8601DateFormatter().string(from: .now))  \(message)")
    }

    private func scheduleActivationWatchdog() {
        activationWatchdog?.cancel()
        activationWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.activationTimedOut()
        }
    }

    private func scheduleSessionWatchdog() {
        sessionWatchdog?.cancel()
        sessionWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 55_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.sessionTimedOut()
        }
    }

    private func activationTimedOut() {
        guard isScanning else { return }
        appendLog("Reader session did not become active within 5 seconds")
        errorMessage = "The NFC reader did not become active. Open Runtime Diagnostics to verify the NFC entitlement and bundle configuration."
        statusMessage = "Reader activation failed"
        session?.invalidate()
    }

    private func sessionTimedOut() {
        guard isScanning else { return }
        appendLog("Reader session watchdog reached 55 seconds")
        errorMessage = "The NFC session timed out. Try again and keep one card near the top of the iPhone."
        statusMessage = "Session timed out"
        session?.invalidate()
    }

    private func resetSessionState(releaseSession: Bool = true) {
        activationWatchdog?.cancel()
        activationWatchdog = nil
        sessionWatchdog?.cancel()
        sessionWatchdog = nil
        isScanning = false
        if releaseSession {
            session = nil
        }
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

        didCompleteCurrentScan = true
        statusMessage = "Card analyzed"
        session.alertMessage = "Card analyzed"
        resetSessionState(releaseSession: false)
        session.invalidate()
    }

    private func friendlyMessage(for error: NFCReaderError) -> String {
        switch error.code {
        case .readerSessionInvalidationErrorUserCanceled:
            return "NFC scan canceled."
        case .readerSessionInvalidationErrorSessionTimeout:
            return "The NFC reader session timed out."
        case .readerSessionInvalidationErrorSystemIsBusy:
            return "NFC is currently busy. Close other NFC/Wallet operations and try again."
        case .readerSessionInvalidationErrorFirstNDEFTagRead:
            return "NFC session completed."
        default:
            return error.localizedDescription
        }
    }
}

extension NFCScanner: NFCTagReaderSessionDelegate {
    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Task { @MainActor in
            self.activationWatchdog?.cancel()
            self.activationWatchdog = nil
            self.statusMessage = "Ready for card"
            self.appendLog("Reader session active")
            self.scheduleSessionWatchdog()
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            let completed = self.didCompleteCurrentScan
            self.resetSessionState()

            if completed {
                self.didCompleteCurrentScan = false
                self.statusMessage = "Card analyzed"
                return
            }

            if let readerError = error as? NFCReaderError {
                let message = self.friendlyMessage(for: readerError)

                if readerError.code == .readerSessionInvalidationErrorUserCanceled {
                    self.statusMessage = "Scan canceled"
                    self.appendLog("Session canceled by user")
                } else {
                    self.statusMessage = "Scan ended"
                    self.errorMessage = message
                    self.appendLog("Session ended: \(message)")
                }
            } else {
                self.statusMessage = "Scan ended"
                self.errorMessage = error.localizedDescription
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

        Task { @MainActor in
            self.statusMessage = "Card detected — connecting…"
            self.appendLog("Tag detected")
        }

        session.connect(to: tag) { error in
            if let error {
                session.invalidate(errorMessage: error.localizedDescription)
                return
            }

            Task { @MainActor in
                self.statusMessage = "Reading public metadata…"
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

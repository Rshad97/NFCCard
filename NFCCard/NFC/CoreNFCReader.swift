import Foundation
import CoreNFC

/// Commands run off the MainActor. Core NFC has its OWN delegate queue so a
/// framework command cannot wait for a callback on the queue it is blocking.
final class CoreNFCReader: NSObject, NFCReaderDriving, NFCTagReaderSessionDelegate {
    private let queue = DispatchQueue(label: "com.rashad.nfccard.reader", qos: .userInitiated)
    private var session: NFCTagReaderSession?
    private var scanID: UUID?
    private var eventHandler: ((UUID, NFCReaderEvent) -> Void)?
    private var isConnecting = false
    private var inspection: NDEFInspection?
    private var stopCompletion: (() -> Void)?
    private var becameActive = false

    func start(scanID: UUID, profile: NFCScanProfile,
               eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
        queue.async {
            guard self.scanID == nil, self.session == nil else {
                eventHandler(scanID, .failure(.init(kind: .busy,
                    message: "The previous NFC session has not closed yet.",
                    diagnostic: "Rejected overlapping Core NFC session")))
                return
            }
            self.scanID = scanID
            self.eventHandler = eventHandler
            self.becameActive = false
            self.emit(.diagnostic("Checking Core NFC availability"))
            let available = NFCReaderSession.readingAvailable
            self.emit(.availability(available))
            self.emit(.diagnostic("Core NFC availability check returned: \(available)"))
            guard available else {
                self.emit(.failure(.init(kind: .unavailable,
                    message: "NFC reading is not available on this device.",
                    diagnostic: "Core NFC readingAvailable=false")))
                return
            }
            let signing = NFCSigningDiagnostics.inspect()
            self.emit(.diagnostic(signing.report))
            if signing.missingTagEntitlement {
                self.emit(.failure(.init(kind: .permission,
                    message: "The installed process does not have the NFC TAG permission. Reinstall the latest package from Sileo and use Restart SpringBoard.",
                    diagnostic: "Runtime signature is missing com.apple.developer.nfc.readersession.formats=TAG")))
                return
            }
            guard let usage = Bundle.main.object(forInfoDictionaryKey: "NFCReaderUsageDescription") as? String,
                  !usage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.emit(.failure(.init(kind: .configuration,
                    message: "The installed app is missing its NFC usage description. Reinstall the latest package.",
                    diagnostic: "Missing NFCReaderUsageDescription")))
                return
            }
            let polling: NFCTagReaderSession.PollingOption = profile == .standard
                ? [.iso14443, .iso15693] : [.iso18092]
            self.emit(.diagnostic("Creating tag reader; polling=\(profile.title), delegate queue=Core NFC default"))
            guard let reader = NFCTagReaderSession(pollingOption: polling, delegate: self, queue: nil) else {
                self.emit(.failure(.init(kind: .configuration,
                    message: "Could not create an NFC reader session.", diagnostic: "NFCTagReaderSession init returned nil")))
                return
            }
            self.session = reader
            self.emit(.diagnostic("Tag reader created; setting prompt"))
            reader.alertMessage = "Hold the top of your iPhone near one NFC card."
            self.emit(.diagnostic("Calling Core NFC begin"))
            reader.begin()
            self.emit(.diagnostic("Core NFC begin returned; waiting for activation"))
        }
    }

    func stop(scanID: UUID, message: String?, completion: @escaping () -> Void) {
        queue.async {
            guard self.scanID == scanID else { completion(); return }
            self.inspection?.cancel()
            self.inspection = nil
            guard let session = self.session else {
                self.clearOwnership()
                completion()
                return
            }
            // Keep the session alive until didInvalidate acknowledges closure.
            // Merely returning from invalidate is not confirmation of closure.
            self.stopCompletion = completion
            if let message { session.invalidate(errorMessage: message) }
            else { session.invalidate() }
        }
    }

    private func clearOwnership() {
        dispatchPrecondition(condition: .onQueue(queue))
        session = nil
        scanID = nil
        eventHandler = nil
        isConnecting = false
        inspection?.cancel()
        inspection = nil
        stopCompletion = nil
    }

    private func emit(_ event: NFCReaderEvent) {
        if let scanID { eventHandler?(scanID, event) }
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        queue.async {
            guard self.session === session, self.stopCompletion == nil else { return }
            self.becameActive = true
            self.emit(.active)
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        queue.async {
            guard self.session === session else { return }
            if let completion = self.stopCompletion {
                self.clearOwnership()
                completion()
                return
            }
            // A spontaneous invalidation already confirms closure. Preserve
            // ownership until the coordinator consumes the failure and stops.
            self.session = nil
            self.inspection?.cancel()
            self.inspection = nil
            self.emit(.diagnostic("Core NFC invalidated; became active=\(self.becameActive)"))
            self.emit(.failure(Self.failure(for: error)))
        }
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        queue.async {
            guard self.session === session, self.stopCompletion == nil, !self.isConnecting, let tag = tags.first else { return }
            guard tags.count == 1 else {
                self.emit(.multipleTags)
                session.alertMessage = "More than one card detected. Present one card only."
                // Avoid tight repeated polling while both cards remain present.
                self.queue.asyncAfter(deadline: .now() + 0.5) {
                    guard self.session === session, self.stopCompletion == nil, !self.isConnecting else { return }
                    session.restartPolling()
                }
                return
            }
            self.isConnecting = true
            self.emit(.connecting)
            session.connect(to: tag) { error in
                self.queue.async {
                    guard self.session === session, self.stopCompletion == nil else { return }
                    if let error {
                        self.emit(.failure(Self.failure(for: error)))
                        return
                    }
                    self.emit(.reading)
                    let card = self.baseProfile(for: tag)
                    self.inspection = NDEFInspector.inspect(tag: tag, queue: self.queue) { metadata in
                        guard self.session === session, self.stopCompletion == nil else { return }
                        var result = card
                        result.ndef = metadata
                        self.emit(.card(result))
                    }
                }
            }
        }
    }

    private static func failure(for error: Error) -> NFCReaderFailure {
        let ns = error as NSError
        let diagnostic = NFCErrorDiagnostics.describe(ns)
        guard let reader = error as? NFCReaderError else {
            return .init(kind: .other, message: ns.localizedDescription, diagnostic: diagnostic)
        }
        switch reader.code {
        case .readerSessionInvalidationErrorUserCanceled:
            return .init(kind: .canceled, message: "Scan canceled.", diagnostic: diagnostic)
        case .readerSessionInvalidationErrorSystemIsBusy:
            return .init(kind: .busy, message: "The system NFC reader is busy. Close any Wallet or NFC session and try again.", diagnostic: diagnostic)
        case .readerSessionInvalidationErrorSessionTimeout:
            return .init(kind: .timeout, message: "The NFC session timed out. Try again.", diagnostic: diagnostic)
        case .readerErrorSecurityViolation:
            return .init(kind: .permission, message: "iOS rejected this app's NFC permission. Share the diagnostic report so the installed signature can be checked.", diagnostic: diagnostic)
        case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
            return .init(kind: .interrupted,
                message: "iOS unexpectedly ended the NFC reader session (202). Close any other NFC or Wallet session and retry once cleanup finishes. If it repeats, share the diagnostic report; this error alone does not identify a card problem.",
                diagnostic: diagnostic)
        default:
            return .init(kind: .other, message: ns.localizedDescription, diagnostic: diagnostic)
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
                    "Initial AID": iso7816.initialSelectedAID
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

}

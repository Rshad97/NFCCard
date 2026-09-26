import Foundation
import Combine

@MainActor
final class NFCScanner: ObservableObject {
    enum Phase { case idle, starting, active, connecting, reading, writing, verifying }
    struct Timeouts {
        var activation: UInt64 = 8_000_000_000
        var session: UInt64 = 55_000_000_000
        var cleanup: UInt64 = 4_000_000_000
        var retryDelay: UInt64 = 750_000_000
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var currentScanProfile = "Idle"
    @Published private(set) var readingAvailable: Bool?
    @Published private(set) var lastCard: NFCCardProfile?
    @Published private(set) var log: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var errorDetails: String?
    @Published private(set) var isRecovering = false
    @Published private(set) var requiresRelaunch = false
    @Published private(set) var lastNDEFRead: NDEFReadResult?
    @Published private(set) var isNDEFOperation = false
    private var isWriteOperation = false

    var isScanning: Bool { activeScanID != nil }
    var canStartScan: Bool { !isScanning && !isRecovering && !requiresRelaunch }
    weak var library: CardLibraryStore?

    private let driver: NFCReaderDriving
    private let timeouts: Timeouts
    private var activeScanID: UUID?
    private var activationWatchdog: Task<Void, Never>?
    private var sessionWatchdog: Task<Void, Never>?
    private var cleanupWatchdog: Task<Void, Never>?
    private var stoppingScanID: UUID?

    init(driver: NFCReaderDriving, timeouts: Timeouts = Timeouts()) {
        self.driver = driver
        self.timeouts = timeouts
    }

    func startScan() { beginScan(profile: .standard) }
    func startFeliCaScan() { beginScan(profile: .felica) }

    func readNDEF(profile: NFCScanProfile = .standard) { beginScan(profile: profile, ndef: .read) }

    /// Explicit local snapshot save, independent of NDEF write support.
    @discardableResult
    func saveNDEFSnapshot() -> Bool {
        guard canStartScan, let result = lastNDEFRead else { return false }
        guard let library else {
            errorMessage = "The card library is not ready. Try again."
            return false
        }
        let card = result.cardSnapshot
        guard library.save(card) else {
            errorMessage = library.storageError ?? "Could not save the card snapshot."
            return false
        }
        lastCard = card
        errorMessage = nil
        appendLog("Public card snapshot saved to Library; identifier and payload omitted")
        return true
    }

    /// Called only from the explicit replacement confirmation, never from detection.
    func writeNDEF(confirmed plan: NDEFWritePlan, profile: NFCScanProfile = .standard) {
        guard canStartScan else { return }
        do {
            guard lastNDEFRead == plan.before else {
                throw NDEFWritePolicy.Failure(reason: "The inspected tag changed. Read it again before writing.")
            }
            try NDEFWritePolicy.validate(plan)
            beginScan(profile: profile, ndef: .write(plan))
        } catch { errorMessage = error.localizedDescription }
    }

    func cancelScan() {
        guard let id = activeScanID else { return }
        finish(id: id, status: isWriteOperation ? "Write canceled — read tag to check" : "Scan canceled",
               error: isWriteOperation ? Self.uncertainWrite : nil)
    }

    func enteredBackground() {
        guard let id = activeScanID else { return }
        finish(id: id, status: "Scan stopped in background", error: isWriteOperation ? Self.uncertainWrite : nil)
    }

    func clearLog() { log.removeAll() }
    func dismissError() { errorMessage = nil }

    var diagnosticReport: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "test"
        return (["NFCCard \(version)", "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                 "Status: \(statusMessage)", "Core NFC available: \(readingAvailable.map { $0 ? "Yes" : "No" } ?? "Not checked")",
                 "Reader cleanup: \(isRecovering ? "Waiting" : requiresRelaunch ? "Unconfirmed; relaunch required" : "Complete")",
                 "Error: \(errorDetails ?? "None")", ""] + log).joined(separator: "\n")
    }

    private static let uncertainWrite = "The write was interrupted. The tag may have changed; read it again to check. No automatic retry was made."

    private func beginScan(profile: NFCScanProfile, ndef: NDEFRequest? = nil) {
        guard canStartScan else { return }
        let id = UUID()
        activeScanID = id
        isNDEFOperation = ndef != nil
        isWriteOperation = ndef?.isWrite == true
        // Inspection is single-use. A retry always needs a new read/confirmation.
        lastNDEFRead = nil
        errorMessage = nil
        errorDetails = nil
        currentScanProfile = ndef == nil ? profile.title : (isWriteOperation ? "NDEF Write" : "NDEF Read")
        phase = .starting
        statusMessage = "Starting \(profile.title) reader…"
        appendLog("Starting \(profile.title), session \(id.uuidString.prefix(8))")

        // Both deadlines start before the driver. No framework call can block
        // the MainActor or prevent these deadlines from releasing UI state.
        activationWatchdog = Task { [weak self, timeouts] in
            try? await Task.sleep(nanoseconds: timeouts.activation)
            guard !Task.isCancelled else { return }
            self?.timedOut(id: id, activation: true)
        }
        sessionWatchdog = Task { [weak self, timeouts] in
            try? await Task.sleep(nanoseconds: timeouts.session)
            guard !Task.isCancelled else { return }
            self?.timedOut(id: id, activation: false)
        }
        let handler: (UUID, NFCReaderEvent) -> Void = { [weak self] id, event in
            Task { @MainActor in self?.receive(event, id: id) }
        }
        if let ndef { driver.startNDEF(scanID: id, profile: profile, request: ndef, eventHandler: handler) }
        else { driver.start(scanID: id, profile: profile, eventHandler: handler) }
    }

    private func receive(_ event: NFCReaderEvent, id: UUID) {
        guard activeScanID == id else { return }
        switch event {
        case .diagnostic(let line):
            appendLog(line)
        case .availability(let available):
            readingAvailable = available
        case .active:
            guard phase == .starting else { return }
            activationWatchdog?.cancel()
            activationWatchdog = nil
            phase = .active
            statusMessage = "Ready for card"
            appendLog("Reader session active")
        case .multipleTags:
            statusMessage = "Present one NFC card only"
        case .connecting:
            activationWatchdog?.cancel()
            phase = .connecting
            statusMessage = "Card detected — connecting…"
            appendLog("Connecting to tag")
        case .reading:
            phase = .reading
            statusMessage = isNDEFOperation ? "Reading NDEF…" : "Reading public metadata…"
            appendLog(isNDEFOperation ? "Reading NDEF; payload omitted from log" : "Reading public metadata")
        case .ndefRead(let result):
            guard isNDEFOperation, !isWriteOperation else { return }
            lastNDEFRead = result
            finish(id: id, status: result.records == nil ? "NDEF unsupported" : "NDEF read complete")
        case .ndefWriting:
            guard isWriteOperation else { return }
            phase = .writing
            statusMessage = "Writing NDEF — hold tag still…"
            appendLog("NDEF write issued; payload omitted")
        case .ndefVerifying:
            guard isWriteOperation else { return }
            phase = .verifying
            statusMessage = "Verifying NDEF by reading back…"
        case .ndefWritten(let result):
            guard isWriteOperation else { return }
            lastNDEFRead = result
            finish(id: id, status: "NDEF written and verified")
        case .card(var card):
            card.matchedModules = CardModuleRegistry.matches(for: card)
            card.capabilities = CapabilityMapService.capabilities(for: card)
            card.privacyInsights = CardPrivacyAnalyzer.analyze(card)
            card.genome = CardGenomeService.fingerprint(card)
            lastCard = card
            library?.save(card)
            appendLog("Analyzed \(card.technology)")
            finish(id: id, status: "Card analyzed")
        case .failure(let failure):
            let canceled = failure.kind == .canceled
            finish(id: id, status: canceled ? "Scan canceled" : "Scan failed",
                   error: canceled ? (isWriteOperation ? Self.uncertainWrite : nil) :
                    ((isWriteOperation && (phase == .writing || phase == .verifying)) ? failure.message + " " + Self.uncertainWrite : failure.message), details: failure.diagnostic,
                   invalidateMessage: canceled ? nil : "NFC scan ended. See NFCCard for details.")
        }
    }

    private func timedOut(id: UUID, activation: Bool) {
        guard activeScanID == id else { return }
        if activation {
            finish(id: id, status: "Reader activation failed",
                   error: "The NFC reader did not activate. No card has been read. Waiting for the previous session to close before another attempt.",
                   details: "Activation deadline expired without a Core NFC active/invalidated callback.",
                   invalidateMessage: "Could not start the NFC reader.")
        } else {
            finish(id: id, status: "Session timed out",
                   error: isWriteOperation ? Self.uncertainWrite : "The NFC scan timed out. Try again with one card near the top of the iPhone.",
                   details: "Session deadline expired.", invalidateMessage: "The NFC scan timed out.")
        }
    }

    private func finish(id: UUID, status: String, error: String? = nil,
                        details: String? = nil, invalidateMessage: String? = nil) {
        guard activeScanID == id else { return }
        // Release the interface immediately, but do not start a second hardware
        // session until the previous session has acknowledged invalidation.
        activeScanID = nil
        let wasWriting = isWriteOperation
        isWriteOperation = false
        isNDEFOperation = false
        activationWatchdog?.cancel()
        activationWatchdog = nil
        sessionWatchdog?.cancel()
        sessionWatchdog = nil
        phase = .idle
        currentScanProfile = "Idle"
        statusMessage = status
        errorMessage = error
        if let details { errorDetails = details }
        appendLog(details.map { "\(status): \($0)" } ?? status)
        stoppingScanID = id
        isRecovering = true
        cleanupWatchdog = Task { [weak self, timeouts] in
            try? await Task.sleep(nanoseconds: timeouts.cleanup)
            guard !Task.isCancelled, let self, self.stoppingScanID == id else { return }
            self.driver.reset(scanID: id)
            self.isRecovering = false
            self.requiresRelaunch = false
            self.errorMessage = "The previous NFC session did not close normally. The stale session was released; you can retry now." + (wasWriting ? " " + Self.uncertainWrite : "")
            self.appendLog("Cleanup deadline expired; stale reader released in-app and retry enabled.")
        }
        driver.stop(scanID: id, message: invalidateMessage) { [weak self] in
            Task { @MainActor in
                guard let self, self.stoppingScanID == id else { return }
                self.cleanupWatchdog?.cancel()
                self.cleanupWatchdog = nil
                // A small settling interval also lets the system sheet dismiss.
                try? await Task.sleep(nanoseconds: self.timeouts.retryDelay)
                guard self.stoppingScanID == id else { return }
                self.stoppingScanID = nil
                let recoveredLate = self.requiresRelaunch
                self.isRecovering = false
                self.requiresRelaunch = false
                if recoveredLate { self.errorMessage = "The NFC session has now closed. You can retry." }
                self.appendLog("Reader cleanup confirmed; ready for another scan.")
            }
        }
    }

    private func appendLog(_ message: String) {
        log.append(ISO8601DateFormatter().string(from: .now) + "  " + message)
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }
}

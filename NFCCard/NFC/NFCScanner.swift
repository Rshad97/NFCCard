import Foundation
import Combine

@MainActor
final class NFCScanner: ObservableObject {
    enum Phase { case idle, starting, active, connecting, reading }
    struct Timeouts {
        var activation: UInt64 = 8_000_000_000
        var session: UInt64 = 55_000_000_000
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var currentScanProfile = "Idle"
    @Published private(set) var readingAvailable: Bool?
    @Published private(set) var lastCard: NFCCardProfile?
    @Published private(set) var log: [String] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var errorDetails: String?

    var isScanning: Bool { activeScanID != nil }
    weak var library: CardLibraryStore?

    private let driver: NFCReaderDriving
    private let timeouts: Timeouts
    private var activeScanID: UUID?
    private var activationWatchdog: Task<Void, Never>?
    private var sessionWatchdog: Task<Void, Never>?

    init(driver: NFCReaderDriving, timeouts: Timeouts = Timeouts()) {
        self.driver = driver
        self.timeouts = timeouts
    }

    func startScan() { beginScan(profile: .standard) }
    func startFeliCaScan() { beginScan(profile: .felica) }

    func cancelScan() {
        guard let id = activeScanID else { return }
        finish(id: id, status: "Scan canceled")
    }

    func enteredBackground() {
        guard let id = activeScanID else { return }
        finish(id: id, status: "Scan stopped in background")
    }

    func clearLog() { log.removeAll() }
    func dismissError() { errorMessage = nil }

    var diagnosticReport: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "test"
        return (["NFCCard \(version)", "OS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                 "Status: \(statusMessage)", "Core NFC available: \(readingAvailable.map { $0 ? "Yes" : "No" } ?? "Not checked")",
                 "Error: \(errorDetails ?? "None")", ""] + log).joined(separator: "\n")
    }

    private func beginScan(profile: NFCScanProfile) {
        guard activeScanID == nil else { return }
        let id = UUID()
        activeScanID = id
        errorMessage = nil
        errorDetails = nil
        currentScanProfile = profile.title
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
        driver.start(scanID: id, profile: profile) { [weak self] id, event in
            Task { @MainActor in self?.receive(event, id: id) }
        }
    }

    private func receive(_ event: NFCReaderEvent, id: UUID) {
        guard activeScanID == id else { return }
        switch event {
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
            statusMessage = "Reading public metadata…"
            appendLog("Reading public metadata")
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
                   error: canceled ? nil : failure.message, details: failure.diagnostic,
                   invalidateMessage: canceled ? nil : "NFC scan ended. See NFCCard for details.")
        }
    }

    private func timedOut(id: UUID, activation: Bool) {
        guard activeScanID == id else { return }
        if activation {
            finish(id: id, status: "Reader activation failed",
                   error: "The NFC reader did not respond. You can retry; if it keeps failing, share the diagnostic report.",
                   details: "Activation deadline expired without a Core NFC active/invalidated callback.",
                   invalidateMessage: "Could not start the NFC reader.")
        } else {
            finish(id: id, status: "Session timed out",
                   error: "The NFC scan timed out. Try again with one card near the top of the iPhone.",
                   details: "Session deadline expired.", invalidateMessage: "The NFC scan timed out.")
        }
    }

    private func finish(id: UUID, status: String, error: String? = nil,
                        details: String? = nil, invalidateMessage: String? = nil) {
        guard activeScanID == id else { return }
        // Clear ownership BEFORE requesting invalidation. The daemon may never
        // acknowledge it; neither the UI nor a later scan depends on that reply.
        activeScanID = nil
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
        driver.stop(scanID: id, message: invalidateMessage)
    }

    private func appendLog(_ message: String) {
        log.append(ISO8601DateFormatter().string(from: .now) + "  " + message)
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }
}

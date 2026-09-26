import XCTest
@testable import NFCCardCore

private final class FakeReader: NFCReaderDriving {
    var starts: [UUID] = []
    var stops: [UUID] = []
    var handlers: [UUID: (UUID, NFCReaderEvent) -> Void] = [:]
    var acknowledgesStop = true
    var completions: [UUID: () -> Void] = [:]
    var ndefRequests: [NDEFRequest] = []
    func startNDEF(scanID: UUID, profile: NFCScanProfile, request: NDEFRequest,
                   eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
        ndefRequests.append(request)
        start(scanID: scanID, profile: profile, eventHandler: eventHandler)
    }
    func start(scanID: UUID, profile: NFCScanProfile, eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
        starts.append(scanID)
        handlers[scanID] = eventHandler
    }
    func stop(scanID: UUID, message: String?, completion: @escaping () -> Void) {
        stops.append(scanID)
        completions[scanID] = completion
        if acknowledgesStop { completion() }
    }

    func reset(scanID: UUID) { completions[scanID]?() }
    func emit(_ event: NFCReaderEvent, for id: UUID? = nil) {
        let target = id ?? starts.last!
        handlers[target]?(target, event)
    }
}

@MainActor
final class NFCScannerTests: XCTestCase {
    private func ndefSnapshot() -> NDEFReadResult {
        NDEFReadResult(identity: "TEST-TAG", technology: "Test NDEF", access: .readWrite, capacity: 4096,
                       records: try! NDEFWritePolicy.draft("private NDEF content", kind: .text), inspectedAt: .now)
    }

    func testNDEFWriteRequiresTheCurrentSuccessfulInspection() async {
        let reader = FakeReader()
        let scanner = NFCScanner(driver: reader, timeouts: .init(retryDelay: 0))
        let inspected = ndefSnapshot()
        let plan = NDEFWritePlan(before: inspected, replacement: try! NDEFWritePolicy.draft("replacement", kind: .text))
        scanner.writeNDEF(confirmed: plan)
        XCTAssertTrue(reader.starts.isEmpty)
        scanner.readNDEF()
        reader.emit(.ndefRead(inspected))
        await eventually { scanner.canStartScan }
        XCTAssertEqual(scanner.lastNDEFRead, inspected)
        XCTAssertFalse(scanner.diagnosticReport.contains("private NDEF content"))
        XCTAssertFalse(scanner.diagnosticReport.contains("TEST-TAG"))
        scanner.writeNDEF(confirmed: plan)
        XCTAssertEqual(reader.starts.count, 2)
        XCTAssertTrue(reader.ndefRequests.last!.isWrite)
        XCTAssertNil(scanner.lastNDEFRead)
        scanner.readNDEF(); scanner.startScan()
        XCTAssertEqual(reader.starts.count, 2, "All operations must share one reader")
        scanner.cancelScan()
        await eventually { scanner.canStartScan }
    }

    func testCanceledWriteWarnsAndDiscardsLateSuccess() async {
        let reader = FakeReader()
        let scanner = NFCScanner(driver: reader, timeouts: .init(retryDelay: 0))
        let inspected = ndefSnapshot()
        scanner.readNDEF(); reader.emit(.ndefRead(inspected))
        await eventually { scanner.canStartScan }
        scanner.writeNDEF(confirmed: .init(before: inspected, replacement: try! NDEFWritePolicy.draft("replacement", kind: .text)))
        reader.emit(.ndefWriting)
        await eventually { scanner.phase == .writing }
        scanner.cancelScan()
        reader.emit(.ndefWritten(inspected))
        await eventually { scanner.canStartScan }
        XCTAssertNil(scanner.lastNDEFRead)
        XCTAssertTrue(scanner.errorMessage?.contains("may have changed") == true)
        XCTAssertFalse(scanner.statusMessage.contains("verified"))
        scanner.writeNDEF(confirmed: .init(before: inspected, replacement: try! NDEFWritePolicy.draft("replacement", kind: .text)))
        XCTAssertEqual(reader.starts.count, 2, "A canceled write cannot reuse an old confirmation")
    }

    func testNDEFBackgroundingCancelsWriteAndNeverSavesItAsCardClone() async {
        let reader = FakeReader()
        let scanner = NFCScanner(driver: reader, timeouts: .init(retryDelay: 0))
        let inspected = ndefSnapshot()
        scanner.readNDEF(); reader.emit(.ndefRead(inspected))
        await eventually { scanner.canStartScan }
        scanner.writeNDEF(confirmed: .init(before: inspected, replacement: try! NDEFWritePolicy.draft("replacement", kind: .text)))
        scanner.enteredBackground()
        await eventually { scanner.canStartScan }
        XCTAssertTrue(scanner.errorMessage?.contains("may have changed") == true)
        XCTAssertNil(scanner.lastCard)
        XCTAssertNil(scanner.lastNDEFRead)
    }

    func testOnlyVerifiedNDEFWriteSetsSuccess() async {
        let reader = FakeReader()
        let scanner = NFCScanner(driver: reader, timeouts: .init(retryDelay: 0))
        let inspected = ndefSnapshot()
        scanner.readNDEF(); reader.emit(.ndefRead(inspected))
        await eventually { scanner.canStartScan }
        let replacement = try! NDEFWritePolicy.draft("replacement", kind: .text)
        scanner.writeNDEF(confirmed: .init(before: inspected, replacement: replacement))
        reader.emit(.ndefVerifying)
        await eventually { scanner.phase == .verifying }
        XCTAssertTrue(scanner.isScanning)
        XCTAssertNil(scanner.lastNDEFRead)
        let result = NDEFReadResult(identity: inspected.identity, technology: inspected.technology,
            access: .readWrite, capacity: inspected.capacity, records: replacement, inspectedAt: .now)
        reader.emit(.ndefWritten(result))
        await eventually { scanner.canStartScan }
        XCTAssertEqual(scanner.statusMessage, "NDEF written and verified")
        XCTAssertEqual(scanner.lastNDEFRead, result)
        XCTAssertNil(scanner.lastCard)
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }

    func testCancelReleasesUIAndRetryDoesNotRequireAppRelaunch() async {
        let driver = FakeReader()
        driver.acknowledgesStop = false
        let subject = NFCScanner(driver: driver, timeouts: .init(cleanup: 20_000_000, retryDelay: 0))
        subject.startScan()
        subject.cancelScan()
        XCTAssertFalse(subject.isScanning)
        XCTAssertEqual(subject.currentScanProfile, "Idle")
        subject.startScan()
        XCTAssertFalse(subject.isScanning)
        XCTAssertEqual(driver.starts.count, 1)
        XCTAssertEqual(driver.stops.count, 1)
        await eventually { subject.canStartScan }
        XCTAssertFalse(subject.isRecovering)
        XCTAssertTrue(subject.canStartScan)
        subject.startScan()
        XCTAssertEqual(driver.starts.count, 2)
    }

    func testActivationTimeoutReleasesUIWithoutAnyDriverCallback() async {
        let driver = FakeReader()
        driver.acknowledgesStop = false
        let scanner = NFCScanner(driver: driver, timeouts: .init(activation: 20_000_000, session: 1_000_000_000, cleanup: 20_000_000, retryDelay: 0))
        scanner.startScan()
        await eventually { !scanner.isScanning }
        XCTAssertEqual(scanner.statusMessage, "Reader activation failed")
        XCTAssertEqual(driver.stops.count, 1)
        XCTAssertNotNil(scanner.errorMessage)
        scanner.startScan()
        XCTAssertFalse(scanner.isScanning)
        XCTAssertEqual(driver.starts.count, 1)
        await eventually { scanner.canStartScan }
        XCTAssertTrue(scanner.canStartScan)
    }

    func testSessionTimeoutRecoversAfterActivation() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver, timeouts: .init(activation: 1_000_000_000, session: 50_000_000))
        scanner.startScan()
        driver.emit(.active)
        await eventually { !scanner.isScanning }
        XCTAssertEqual(scanner.statusMessage, "Session timed out")
        XCTAssertEqual(driver.stops.count, 1)
    }

    func testOldErrorAndActivationCannotCancelNewScan() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        let first = driver.starts[0]
        scanner.cancelScan()
        await eventually { scanner.canStartScan }
        scanner.startScan()
        driver.emit(.failure(.init(kind: .other, message: "Old failure", diagnostic: "old")), for: first)
        driver.emit(.active, for: first)
        driver.emit(.reading)
        await eventually { scanner.phase == .reading }
        XCTAssertNil(scanner.errorMessage)
        XCTAssertTrue(scanner.isScanning)
        scanner.cancelScan()
    }

    func testLateCardAfterCancelIsDiscarded() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        let first = driver.starts[0]
        scanner.cancelScan()
        driver.emit(.card(.init(technology: "Late result")), for: first)
        await eventually { scanner.canStartScan }
        scanner.startScan()
        driver.emit(.active)
        await eventually { scanner.phase == .active }
        XCTAssertNil(scanner.lastCard)
        scanner.cancelScan()
    }

    func testSuccessReleasesSessionAndIgnoresSubsequentInvalidation() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        driver.emit(.card(.init(technology: "ISO 15693")))
        driver.emit(.failure(.init(kind: .canceled, message: "Canceled", diagnostic: "NFCError (200)")))
        await eventually { !scanner.isScanning }
        XCTAssertEqual(scanner.statusMessage, "Card analyzed")
        XCTAssertNotNil(scanner.lastCard?.genome)
        XCTAssertNil(scanner.errorMessage)
        XCTAssertEqual(driver.stops.count, 1)
    }

    func testPermissionFailurePreservesDiagnosticAndAllowsRetry() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        driver.emit(.failure(.init(kind: .permission, message: "Permission rejected", diagnostic: "NFCError (2): Missing required entitlement")))
        await eventually { !scanner.isScanning }
        XCTAssertTrue(scanner.diagnosticReport.contains("NFCError (2)"))
        scanner.dismissError()
        XCTAssertNil(scanner.errorMessage)
        XCTAssertNotNil(scanner.errorDetails)
        await eventually { scanner.canStartScan }
        scanner.startScan()
        XCTAssertTrue(scanner.isScanning)
        scanner.cancelScan()
    }

    func testUnavailableReaderDoesNotLeaveScanDisabled() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        driver.emit(.availability(false))
        driver.emit(.failure(.init(kind: .unavailable, message: "Unavailable", diagnostic: "Unavailable")))
        await eventually { !scanner.isScanning }
        XCTAssertEqual(scanner.readingAvailable, false)
        XCTAssertNotNil(scanner.errorMessage)
    }

    func testDuplicateStartAndCancelAreIdempotent() {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        scanner.startScan()
        scanner.startFeliCaScan()
        XCTAssertEqual(driver.starts.count, 1)
        scanner.cancelScan()
        scanner.cancelScan()
        XCTAssertEqual(driver.stops.count, 1)
    }

    func testBackgroundAlwaysReleasesSession() {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        scanner.enteredBackground()
        XCTAssertFalse(scanner.isScanning)
        XCTAssertEqual(scanner.statusMessage, "Scan stopped in background")
        XCTAssertEqual(driver.stops.count, 1)
    }

    func testDiagnosticLogStaysBoundedAcrossRepeatedFailures() async {
        let scanner = NFCScanner(driver: FakeReader(), timeouts: .init(retryDelay: 0))
        for _ in 0..<200 {
            scanner.startScan(); scanner.cancelScan()
            await eventually { scanner.canStartScan }
        }
        XCTAssertEqual(scanner.log.count, 300)
        scanner.clearLog()
        XCTAssertTrue(scanner.log.isEmpty)
    }

    func testBlockedWorkerDoesNotBlockUIOrItsTimeout() async {
        final class BlockedReader: NFCReaderDriving {
            let gate = DispatchSemaphore(value: 0)
            let queue = DispatchQueue(label: "test.blocked.nfc")
            func start(scanID: UUID, profile: NFCScanProfile, eventHandler: @escaping (UUID, NFCReaderEvent) -> Void) {
                queue.async { self.gate.wait() }
            }
            func stop(scanID: UUID, message: String?, completion: @escaping () -> Void) { queue.async { completion() } }
            func reset(scanID: UUID) { gate.signal() }
        }
        let driver = BlockedReader()
        defer { driver.gate.signal() }
        let scanner = NFCScanner(driver: driver, timeouts: .init(activation: 20_000_000, session: 1_000_000_000))
        scanner.startScan()
        var mainActorStillRuns = false
        Task { @MainActor in mainActorStillRuns = true }
        await eventually { !scanner.isScanning && mainActorStillRuns }
        XCTAssertNotNil(scanner.errorMessage)
    }

    func testRetryWaitsForExplicitCleanupAndStaleCompletionCannotUnlockNewScan() async {
        let driver = FakeReader()
        driver.acknowledgesStop = false
        let scanner = NFCScanner(driver: driver, timeouts: .init(retryDelay: 0))
        scanner.startScan()
        let first = driver.starts[0]
        scanner.cancelScan()
        scanner.startFeliCaScan()
        XCTAssertEqual(driver.starts.count, 1)
        driver.completions[first]?()
        await eventually { scanner.canStartScan }
        scanner.startScan()
        scanner.cancelScan()
        driver.completions[first]?()
        driver.emit(.active, for: first)
        await Task.yield()
        XCTAssertTrue(scanner.isRecovering)
        XCTAssertFalse(scanner.canStartScan)
        driver.completions[driver.starts[1]]?()
        await eventually { scanner.canStartScan }
    }

    func testLateCleanupCanRecoverWithoutRestartAndPreservesOriginalError() async {
        let driver = FakeReader()
        driver.acknowledgesStop = false
        let scanner = NFCScanner(driver: driver, timeouts: .init(cleanup: 20_000_000, retryDelay: 0))
        scanner.startScan()
        driver.emit(.failure(.init(kind: .interrupted, message: "Unexpected termination", diagnostic: "NFCError (202)")))
        await eventually { scanner.canStartScan }
        driver.completions[driver.starts[0]]?()
        await eventually { scanner.canStartScan }
        XCTAssertFalse(scanner.requiresRelaunch)
        XCTAssertEqual(scanner.errorDetails, "NFCError (202)")
        XCTAssertTrue(scanner.diagnosticReport.contains("Cleanup deadline expired"))
    }

    func testError202ThenSilentActivationDoesNotCreateEndlessSessions() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver, timeouts: .init(activation: 40_000_000, cleanup: 20_000_000, retryDelay: 0))
        scanner.startScan()
        driver.emit(.failure(.init(kind: .interrupted, message: "Unexpected termination", diagnostic: "NFCError (202)")))
        await eventually { scanner.canStartScan }
        driver.acknowledgesStop = false
        scanner.startScan()
        await eventually { scanner.canStartScan }
        XCTAssertEqual(driver.starts.count, 2)
        XCTAssertFalse(scanner.isScanning)
        XCTAssertTrue(scanner.diagnosticReport.contains("NFCError (202)"))
        XCTAssertTrue(scanner.diagnosticReport.contains("Activation deadline expired"))
    }

    func testDiagnosticStagesArePreservedInReport() async {
        let driver = FakeReader()
        let scanner = NFCScanner(driver: driver)
        scanner.startScan()
        driver.emit(.diagnostic("Runtime entitlements: formats=TAG"))
        driver.emit(.diagnostic("Calling Core NFC begin"))
        await eventually { scanner.log.contains { $0.contains("Calling Core NFC begin") } }
        XCTAssertTrue(scanner.diagnosticReport.contains("formats=TAG"))
        scanner.cancelScan()
    }

    func testNestedNFCErrorPreservesUnderlyingCauseWithoutArbitraryUserInfo() {
        let underlying = NSError(domain: "NSCocoaErrorDomain", code: 4099,
                                 userInfo: [NSLocalizedDescriptionKey: "XPC connection invalidated"])
        let error = NSError(domain: "NFCError", code: 202,
                            userInfo: [NSLocalizedDescriptionKey: "Session invalidated unexpectedly",
                                       NSUnderlyingErrorKey: underlying, "privateCardData": "do-not-export"])
        let report = NFCErrorDiagnostics.describe(error)
        XCTAssertTrue(report.contains("NFCError (202)"))
        XCTAssertTrue(report.contains("NSCocoaErrorDomain (4099)"))
        XCTAssertFalse(report.contains("do-not-export"))
    }
}

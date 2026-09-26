import XCTest
@testable import NFCCardCore

private let testTime = Date(timeIntervalSince1970: 1_700_000_000)
private func testNDEFRecords(_ text: String = "before") -> [NDEFRecordData] {
    try! NDEFWritePolicy.draft(text, kind: .text)
}
private func snapshot(identity: String = "TEST-TAG", access: NDEFMetadata.Access = .readWrite,
                      capacity: Int = 4096, records: [NDEFRecordData]? = testNDEFRecords(),
                      date: Date = testTime) -> NDEFReadResult {
    NDEFReadResult(identity: identity, technology: "Test NDEF", access: access,
                   capacity: capacity, records: records, inspectedAt: date)
}

final class NDEFWritePolicyTests: XCTestCase {
    func testUTF8TextRoundTripAndExactEncodedLength() throws {
        let message = try NDEFWritePolicy.draft("مرحبا", kind: .text)
        XCTAssertEqual(message[0].displayValue, "مرحبا")
        XCTAssertEqual(message[0].payload.prefix(3), Data([2, 101, 110]))
        XCTAssertEqual(NDEFWritePolicy.byteCount(message), "مرحبا".utf8.count + 7)
    }
    func testLongRecordHeaderBoundary() {
        XCTAssertEqual(testNDEFRecords(String(repeating: "a", count: 252))[0].encodedLength, 259)
        XCTAssertEqual(testNDEFRecords(String(repeating: "a", count: 253))[0].encodedLength, 263)
    }
    func testURLRoundTripAndUnsupportedSchemesRejected() throws {
        let message = try NDEFWritePolicy.draft("https://example.com/test", kind: .url)
        XCTAssertEqual(message[0].displayValue, "https://example.com/test")
        for value in ["javascript:alert(1)", "file:///etc/test", "ftp://example.com", "https://", "https://user:secret@example.com", "https://exam ple.com", "https://example.com\n"] {
            XCTAssertThrowsError(try NDEFWritePolicy.draft(value, kind: .url))
        }
    }
    func testEmptyAndOversizeDraftsRejectedInBytes() {
        for value in ["", " \n", String(repeating: "ع", count: 2049)] {
            XCTAssertThrowsError(try NDEFWritePolicy.draft(value, kind: .text))
        }
    }
    func testReadOnlyUnsupportedUnknownAndMissingIdentityCannotWrite() {
        for before in [snapshot(access: .readOnly), snapshot(access: .unsupported), snapshot(access: .unknown), snapshot(identity: ""), snapshot(records: nil)] {
            XCTAssertThrowsError(try NDEFWritePolicy.validate(NDEFWritePlan(before: before, replacement: testNDEFRecords("new")), now: testTime))
        }
    }
    func testCapacityIncludesRecordOverhead() {
        let replacement = testNDEFRecords("new")
        let count = NDEFWritePolicy.byteCount(replacement)
        XCTAssertNoThrow(try NDEFWritePolicy.validate(NDEFWritePlan(before: snapshot(capacity: count), replacement: replacement), now: testTime))
        XCTAssertThrowsError(try NDEFWritePolicy.validate(NDEFWritePlan(before: snapshot(capacity: count - 1), replacement: replacement), now: testTime))
    }
    func testExpiredAndFutureInspectionRejected() {
        for seconds in [-121.0, 1.0] {
            let plan = NDEFWritePlan(before: snapshot(date: testTime.addingTimeInterval(seconds)), replacement: testNDEFRecords("new"))
            XCTAssertThrowsError(try NDEFWritePolicy.validate(plan, now: testTime))
        }
    }
    func testMalformedReplacementAndMultipleRecordsRejected() {
        let malformed = NDEFRecordData(format: 1, type: Data([0x54]), identifier: Data(), payload: Data([63]))
        for replacement in [[], [malformed], testNDEFRecords() + testNDEFRecords()] {
            XCTAssertThrowsError(try NDEFWritePolicy.validate(NDEFWritePlan(before: snapshot(), replacement: replacement), now: testTime))
        }
    }
    func testChangedTagContentOrStatusRejected() {
        let plan = NDEFWritePlan(before: snapshot(), replacement: testNDEFRecords("new"))
        for current in [snapshot(identity: "OTHER-TAG"), snapshot(records: testNDEFRecords("changed")), snapshot(access: .readOnly), snapshot(capacity: 1)] {
            XCTAssertThrowsError(try NDEFWritePolicy.validateTarget(current, plan: plan, now: testTime))
        }
    }
    func testReadLimitsAndMalformedTextDoNotCrash() {
        XCTAssertThrowsError(try NDEFWritePolicy.validateRead(Array(repeating: testNDEFRecords()[0], count: 129)))
        let huge = NDEFRecordData(format: 1, type: Data([0x54]), identifier: Data(), payload: Data(repeating: 1, count: 65_536))
        XCTAssertThrowsError(try NDEFWritePolicy.validateRead([huge]))
        let short = NDEFRecordData(format: 1, type: Data([0x54]), identifier: Data(), payload: Data([63]))
        XCTAssertEqual(short.displayValue, "3F")
    }
}

private final class FakeNDEFTag: NDEFTagAccessing {
    var identity = "TEST-TAG"
    var technology = "Test NDEF"
    var queryCallback: ((Result<NDEFTagStatus, Error>) -> Void)?
    var reads: [(Result<[NDEFRecordData], Error>) -> Void] = []
    var writes: [[NDEFRecordData]] = []
    var writeCallback: ((Error?) -> Void)?
    func query(_ completion: @escaping (Result<NDEFTagStatus, Error>) -> Void) { queryCallback = completion }
    func read(_ completion: @escaping (Result<[NDEFRecordData], Error>) -> Void) { reads.append(completion) }
    func write(_ records: [NDEFRecordData], completion: @escaping (Error?) -> Void) {
        writes.append(records); writeCallback = completion
    }
}

private final class TransactionHarness {
    let queue = DispatchQueue(label: "ndef-test")
    let tag = FakeNDEFTag()
    var events: [NDEFTransaction.Event] = []
    var transaction: NDEFTransaction!
    init(_ request: NDEFRequest = .write(NDEFWritePlan(before: snapshot(), replacement: testNDEFRecords("after")))) {
        transaction = NDEFTransaction(tag: tag, request: request, queue: queue, now: { testTime }) { [weak self] in self?.events.append($0) }
        queue.sync { transaction.start() }
    }
    func status(_ access: NDEFMetadata.Access = .readWrite, capacity: Int = 4096) {
        tag.queryCallback?(.success(NDEFTagStatus(access: access, capacity: capacity)))
        flush()
    }
    func read(_ value: [NDEFRecordData] = testNDEFRecords(), index: Int = 0) {
        tag.reads[index](.success(value)); flush()
    }
    func wrote(error: Error? = nil) { tag.writeCallback?(error); flush() }
    func cancel() { queue.sync { transaction.cancel() } }
    func flush() { queue.sync {} }
    var failed: Bool { events.contains { if case .failed = $0 { return true }; return false } }
    var verified: Bool { events.contains { if case .verified = $0 { return true }; return false } }
}

final class NDEFTransactionTests: XCTestCase {
    func testReadNeverWritesAndReturnsFullMessage() {
        let h = TransactionHarness(.read)
        h.status(.readOnly); h.read(testNDEFRecords("read only content"))
        XCTAssertTrue(h.tag.writes.isEmpty)
        guard case .read(let result)? = h.events.last else { return XCTFail("No read result") }
        XCTAssertEqual(result.records, testNDEFRecords("read only content"))
        XCTAssertEqual(result.access, .readOnly)
    }
    func testUnsupportedReadReturnsUnsupportedWithoutTryingToRead() {
        let h = TransactionHarness(.read); h.status(.unsupported)
        XCTAssertTrue(h.tag.reads.isEmpty)
        XCTAssertTrue(h.tag.writes.isEmpty)
        guard case .read(let result)? = h.events.last else { return XCTFail("No unsupported result") }
        XCTAssertNil(result.records)
    }
    func testUnsupportedAndReadOnlyWriteNeverIssueWrite() {
        for access in [NDEFMetadata.Access.unsupported, .readOnly, .unknown] {
            let h = TransactionHarness(); h.status(access)
            XCTAssertTrue(h.failed)
            XCTAssertTrue(h.tag.reads.isEmpty)
            XCTAssertTrue(h.tag.writes.isEmpty)
        }
    }
    func testQueryErrorDoesNotFallThroughToWrite() {
        let h = TransactionHarness()
        h.tag.queryCallback?(.failure(NDEFWritePolicy.Failure(reason: "query failure"))); h.flush()
        XCTAssertTrue(h.failed)
        XCTAssertTrue(h.tag.reads.isEmpty)
        XCTAssertTrue(h.tag.writes.isEmpty)
    }
    func testReadErrorIsNotTreatedAsBlankTag() {
        let h = TransactionHarness(); h.status()
        h.tag.reads[0](.failure(NDEFWritePolicy.Failure(reason: "read failure"))); h.flush()
        XCTAssertTrue(h.failed)
        XCTAssertTrue(h.tag.writes.isEmpty)
    }
    func testWrongIdentityAndTechnologyNeverWrite() {
        for changedTechnology in [false, true] {
            let h = TransactionHarness()
            if changedTechnology { h.tag.technology = "Other" } else { h.tag.identity = "OTHER-TAG" }
            h.status()
            XCTAssertTrue(h.failed)
            XCTAssertTrue(h.tag.writes.isEmpty)
        }
    }
    func testChangedContentAndReducedCapacityPreventWrite() {
        let changed = TransactionHarness(); changed.status(); changed.read(testNDEFRecords("changed"))
        XCTAssertTrue(changed.failed); XCTAssertTrue(changed.tag.writes.isEmpty)
        let small = TransactionHarness(); small.status(capacity: 1); small.read()
        XCTAssertTrue(small.failed); XCTAssertTrue(small.tag.writes.isEmpty)
    }
    func testBlankWritableTagCanBeWrittenAndVerified() {
        let h = TransactionHarness(.write(NDEFWritePlan(before: snapshot(records: []), replacement: testNDEFRecords("after"))))
        h.status(); h.read([]); h.wrote(); h.read(testNDEFRecords("after"), index: 1)
        XCTAssertEqual(h.tag.writes.count, 1)
        XCTAssertTrue(h.verified)
    }
    func testWriteSuccessIsNotReportedUntilExactReadBack() {
        let h = TransactionHarness(); h.status(); h.read()
        XCTAssertEqual(h.tag.writes, [testNDEFRecords("after")])
        XCTAssertFalse(h.verified)
        h.wrote(); XCTAssertFalse(h.verified)
        h.read(testNDEFRecords("after"), index: 1)
        XCTAssertTrue(h.verified); XCTAssertFalse(h.failed)
    }
    func testWriteErrorDoesNotRetryOrClaimSuccess() {
        let h = TransactionHarness(); h.status(); h.read()
        h.wrote(error: NDEFWritePolicy.Failure(reason: "connection lost"))
        XCTAssertEqual(h.tag.writes.count, 1)
        XCTAssertEqual(h.tag.reads.count, 1)
        XCTAssertTrue(h.failed); XCTAssertFalse(h.verified)
    }
    func testVerificationMismatchAndErrorAreFailures() {
        let h = TransactionHarness(); h.status(); h.read(); h.wrote()
        h.read(testNDEFRecords("unexpected"), index: 1)
        XCTAssertTrue(h.failed); XCTAssertFalse(h.verified)
        let error = TransactionHarness(); error.status(); error.read(); error.wrote()
        error.tag.reads[1](.failure(NDEFWritePolicy.Failure(reason: "removed"))); error.flush()
        XCTAssertTrue(error.failed); XCTAssertFalse(error.verified)
        XCTAssertEqual(error.tag.writes.count, 1)
    }
    func testCancelBeforeQueryAndReadCallbacksPreventsAnyWrite() {
        let querying = TransactionHarness(); querying.cancel(); querying.status()
        XCTAssertTrue(querying.tag.reads.isEmpty); XCTAssertTrue(querying.tag.writes.isEmpty)
        let reading = TransactionHarness(); reading.status(); reading.cancel(); reading.read()
        XCTAssertTrue(reading.tag.writes.isEmpty); XCTAssertTrue(reading.events.isEmpty)
    }
    func testCancelDuringWritePreventsLateVerificationAndSuccess() {
        let h = TransactionHarness(); h.status(); h.read(); h.cancel(); h.wrote()
        XCTAssertEqual(h.tag.writes.count, 1); XCTAssertEqual(h.tag.reads.count, 1)
        XCTAssertFalse(h.verified)
    }
    func testDuplicateCallbacksNeverCauseDuplicateWrite() {
        let h = TransactionHarness(); h.status(); h.status(); h.read(); h.read(); h.wrote(); h.wrote()
        XCTAssertEqual(h.tag.writes.count, 1); XCTAssertEqual(h.tag.reads.count, 2)
        h.read(testNDEFRecords("after"), index: 1); h.read(testNDEFRecords("after"), index: 1)
        XCTAssertEqual(h.events.filter { if case .verified = $0 { return true }; return false }.count, 1)
    }
    func testExpiredConfirmationNeverReadsOrWrites() {
        let h = TransactionHarness(.write(NDEFWritePlan(before: snapshot(date: testTime.addingTimeInterval(-121)), replacement: testNDEFRecords("after"))))
        h.status(); XCTAssertTrue(h.failed)
        XCTAssertTrue(h.tag.reads.isEmpty); XCTAssertTrue(h.tag.writes.isEmpty)
    }
}

import Foundation

struct NDEFTagStatus {
    let access: NDEFMetadata.Access
    let capacity: Int
}

protocol NDEFTagAccessing: AnyObject {
    var identity: String { get }
    var technology: String { get }
    func query(_ completion: @escaping (Result<NDEFTagStatus, Error>) -> Void)
    func read(_ completion: @escaping (Result<[NDEFRecordData], Error>) -> Void)
    func write(_ records: [NDEFRecordData], completion: @escaping (Error?) -> Void)
}

/// The real Core NFC adapter and test doubles use this same guarded transaction.
/// Every callback re-enters the reader queue; cancellation prevents late writes.
final class NDEFTransaction {
    enum Stage { case idle, querying, reading, writing, verifying, finished }
    enum Event {
        case writing, verifying
        case read(NDEFReadResult), verified(NDEFReadResult)
        case failed(String)
    }
    private let tag: NDEFTagAccessing
    private let request: NDEFRequest
    private let queue: DispatchQueue
    private let now: () -> Date
    private var handler: ((Event) -> Void)?
    private var stage: Stage = .idle

    init(tag: NDEFTagAccessing, request: NDEFRequest, queue: DispatchQueue,
         now: @escaping () -> Date = { .now }, handler: @escaping (Event) -> Void) {
        self.tag = tag; self.request = request; self.queue = queue; self.now = now; self.handler = handler
    }

    func start() {
        dispatchPrecondition(condition: .onQueue(queue))
        guard stage == .idle else { return }
        stage = .querying
        tag.query { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard self.stage == .querying else { return }
                do {
                    let status = try result.get()
                    guard status.access == .readOnly || status.access == .readWrite else {
                        if self.request.isWrite { self.fail("This card does not support writable NDEF. Nothing was written.") }
                        else { self.finish(.read(self.snapshot(status: status, records: nil))) }
                        return
                    }
                    if case .write(let plan) = self.request {
                        try NDEFWritePolicy.validate(plan, now: self.now())
                        guard self.tag.identity == plan.before.identity, self.tag.technology == plan.before.technology,
                              status.access == .readWrite else {
                            self.fail("Wrong tag or tag is read-only. Nothing was written.")
                            return
                        }
                    }
                    self.readInitial(status)
                } catch { self.fail("Could not inspect NDEF: \(error.localizedDescription) Nothing was written.") }
            }
        }
    }

    func cancel() {
        dispatchPrecondition(condition: .onQueue(queue))
        stage = .finished
        handler = nil
    }

    private func readInitial(_ status: NDEFTagStatus) {
        stage = .reading
        tag.read { [weak self] result in
            guard let self else { return }
            self.queue.async {
                guard self.stage == .reading else { return }
                do {
                    let records = try result.get()
                    try NDEFWritePolicy.validateRead(records)
                    let snapshot = self.snapshot(status: status, records: records)
                    switch self.request {
                    case .read: self.finish(.read(snapshot))
                    case .write(let plan):
                        try NDEFWritePolicy.validateTarget(snapshot, plan: plan, now: self.now())
                        self.write(plan, status: status)
                    }
                } catch { self.fail("Could not prepare NDEF: \(error.localizedDescription) Nothing was written.") }
            }
        }
    }

    private func write(_ plan: NDEFWritePlan, status: NDEFTagStatus) {
        // No automatic retries: a failed transport can still have modified a tag.
        stage = .writing
        handler?(.writing)
        guard stage == .writing else { return }
        tag.write(plan.replacement) { [weak self] error in
            guard let self else { return }
            self.queue.async {
                guard self.stage == .writing else { return }
                if error != nil {
                    self.fail("Write could not be confirmed. The tag may have changed. Read it again; no automatic retry was made.")
                    return
                }
                self.stage = .verifying
                self.handler?(.verifying)
                guard self.stage == .verifying else { return }
                self.tag.read { [weak self] result in
                    guard let self else { return }
                    self.queue.async {
                        guard self.stage == .verifying else { return }
                        do {
                            let actual = try result.get()
                            guard actual == plan.replacement else {
                                self.fail("Write returned, but read-back did not match. The tag may have changed. Read it again.")
                                return
                            }
                            self.finish(.verified(self.snapshot(status: status, records: actual)))
                        } catch { self.fail("Write returned, but verification failed. The tag may have changed. Read it again.") }
                    }
                }
            }
        }
    }

    private func snapshot(status: NDEFTagStatus, records: [NDEFRecordData]?) -> NDEFReadResult {
        NDEFReadResult(identity: tag.identity, technology: tag.technology, access: status.access,
                       capacity: max(0, status.capacity), records: records, inspectedAt: now())
    }
    private func fail(_ message: String) { finish(.failed(message)) }
    private func finish(_ event: Event) {
        guard stage != .finished else { return }
        let callback = handler
        cancel()
        callback?(event)
    }
}

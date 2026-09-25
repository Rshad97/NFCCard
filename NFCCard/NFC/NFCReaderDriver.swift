import Foundation

enum NFCScanProfile {
    case standard
    case felica

    var title: String {
        switch self {
        case .standard: return "Standard NFC"
        case .felica: return "FeliCa / NFC-F"
        }
    }
}

struct NFCReaderFailure: Error {
    enum Kind { case canceled, unavailable, permission, busy, timeout, configuration, interrupted, other }
    let kind: Kind
    let message: String
    let diagnostic: String
}

enum NFCReaderEvent {
    case diagnostic(String)
    case availability(Bool)
    case active
    case multipleTags
    case connecting
    case reading
    case card(NFCCardProfile)
    case failure(NFCReaderFailure)
}

/// Implementations must enqueue work and return promptly, including stop().
/// Core NFC/XPC calls must never run on the UI executor.
protocol NFCReaderDriving: AnyObject {
    func start(scanID: UUID, profile: NFCScanProfile,
               eventHandler: @escaping (UUID, NFCReaderEvent) -> Void)
    /// Completion means the session is invalidated (or was never created), not
    /// merely that an invalidate request has been submitted to Core NFC.
    func stop(scanID: UUID, message: String?, completion: @escaping () -> Void)
    func reset(scanID: UUID)
}

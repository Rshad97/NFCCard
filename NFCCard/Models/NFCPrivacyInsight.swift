import Foundation

struct NFCPrivacyInsight: Identifiable, Codable, Hashable {
    enum Severity: String, Codable {
        case info
        case notice
        case warning
    }

    let id: UUID
    let title: String
    let detail: String
    let severity: Severity

    init(id: UUID = UUID(), title: String, detail: String, severity: Severity) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

import Foundation

enum CardExportService {
    static func jsonData(for card: NFCCardProfile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(card)
    }
}

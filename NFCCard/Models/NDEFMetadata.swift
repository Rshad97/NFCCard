import Foundation

struct NDEFRecordSummary: Identifiable, Codable, Hashable {
    let id: UUID
    let typeNameFormat: String
    let type: String
    let identifierHex: String
    let payloadPreview: String
    let payloadLength: Int

    init(
        id: UUID = UUID(),
        typeNameFormat: String,
        type: String,
        identifierHex: String,
        payloadPreview: String,
        payloadLength: Int
    ) {
        self.id = id
        self.typeNameFormat = typeNameFormat
        self.type = type
        self.identifierHex = identifierHex
        self.payloadPreview = payloadPreview
        self.payloadLength = payloadLength
    }
}

struct NDEFMetadata: Codable, Hashable {
    enum Access: String, Codable {
        case unsupported
        case readOnly
        case readWrite
        case unknown
    }

    var access: Access = .unknown
    var capacity: Int = 0
    var records: [NDEFRecordSummary] = []
}

import Foundation

struct ProtocolEvidence: Identifiable, Hashable {
    let source: String
    let observation: String
    let interpretation: String
    let weight: Double

    var id: String { "\(source)|\(observation)" }
}

struct ProtocolAtlasReport: Hashable {
    let family: String
    let variant: String
    let confidence: Double
    let evidence: [ProtocolEvidence]
    let nextReadOnlyProbes: [String]
    let limitations: [String]

    var confidencePercent: Int {
        Int((min(max(confidence, 0), 1) * 100).rounded())
    }
}

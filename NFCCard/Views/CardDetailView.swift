import SwiftUI

struct CardDetailView: View {
    let card: NFCCardProfile

    var body: some View {
        List {
            Section("Identity") {
                LabeledContent("Technology", value: card.technology)
                if let subtype = card.subtype, !subtype.isEmpty {
                    LabeledContent("Subtype", value: subtype)
                }
                if let uid = card.uidHex {
                    LabeledContent("UID") {
                        Text(uid).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if let genome = card.genome {
                    LabeledContent("Card Genome") {
                        Text(String(genome.prefix(16)).uppercased())
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            if !card.matchedModules.isEmpty {
                Section("Protocol Lens") {
                    ForEach(card.matchedModules, id: \.self) { module in
                        Label(module, systemImage: "puzzlepiece.extension")
                    }
                }
            }

            if let ndef = card.ndef {
                Section("NDEF") {
                    LabeledContent("Access", value: ndef.access.rawValue)
                    LabeledContent("Capacity", value: "\(ndef.capacity) bytes")
                    LabeledContent("Records", value: "\(ndef.records.count)")
                    ForEach(ndef.records) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.type.isEmpty ? record.typeNameFormat : record.type).font(.headline)
                            Text(record.payloadPreview).font(.caption.monospaced()).lineLimit(3)
                            Text("\(record.payloadLength) bytes").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !card.details.isEmpty {
                Section("Technical Data") {
                    ForEach(card.details.keys.sorted(), id: \.self) { key in
                        LabeledContent(key) {
                            Text(card.details[key] ?? "—")
                                .font(.caption.monospaced())
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
        .navigationTitle("Card Snapshot")
    }
}

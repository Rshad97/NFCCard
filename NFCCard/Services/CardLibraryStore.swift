import Foundation

@MainActor
final class CardLibraryStore: ObservableObject {
    @Published private(set) var cards: [NFCCardProfile] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("NFCCard", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("cards.json")
        load()
    }

    func save(_ card: NFCCardProfile) {
        if let genome = card.genome,
           let index = cards.firstIndex(where: { $0.genome == genome }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            cards.remove(at: index)
        }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.nfccard.decode([NFCCardProfile].self, from: data) else { return }
        cards = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder.nfccard.encode(cards) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var nfccard: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var nfccard: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

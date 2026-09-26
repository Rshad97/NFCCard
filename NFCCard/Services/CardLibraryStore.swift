import Foundation
import Combine

@MainActor
final class CardLibraryStore: ObservableObject {
    @Published private(set) var cards: [NFCCardProfile] = []
    @Published private(set) var storageError: String?

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            load()
            return
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("NFCCard", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            storageError = "Could not create the card library directory: \(error.localizedDescription)"
        }

        self.fileURL = directory.appendingPathComponent("cards.json")
        load()
    }

    @discardableResult
    func save(_ card: NFCCardProfile) -> Bool {
        let previous = cards
        if let genome = card.genome,
           let index = cards.firstIndex(where: { $0.genome == genome }) {
            cards[index] = card
        } else {
            cards.insert(card, at: 0)
        }
        if persist() { return true }
        cards = previous
        return false
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            cards.remove(at: index)
        }
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            cards = try JSONDecoder.nfccard.decode([NFCCardProfile].self, from: data)
            storageError = nil
        } catch {
            storageError = "Could not read the card library: \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            let data = try JSONEncoder.nfccard.encode(cards)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            storageError = nil
            return true
        } catch {
            storageError = "Could not save the card library: \(error.localizedDescription)"
            return false
        }
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

import XCTest
@testable import NFCCardCore

@MainActor
final class CardLibraryStoreIdentityTests: XCTestCase {
    func testStableIDUpdatesSnapshotWhenGenomeChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("cards.json")
        let store = CardLibraryStore(fileURL: url)
        let id = UUID()

        let original = NFCCardProfile(
            id: id,
            name: "Card",
            technology: "ISO 7816",
            uidHex: "01020304",
            genome: "old-genome"
        )
        XCTAssertTrue(store.save(original))

        var updated = original
        updated.genome = "new-genome"
        updated.subtype = "MIFARE DESFire-compatible"
        updated.details["DESFire Probe"] = "DESFire-compatible GetVersion response"

        XCTAssertTrue(store.save(updated))
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards.first?.id, id)
        XCTAssertEqual(store.cards.first?.genome, "new-genome")
        XCTAssertEqual(store.cards.first?.subtype, "MIFARE DESFire-compatible")
    }
}

import XCTest
@testable import NFCCardCore

final class WalletPassTests: XCTestCase {
    private let card = NFCCardProfile(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        technology: "ISO 7816", uidHex: "01020304050607", subtype: "D2760000850101",
        details: ["Secret fixture": "MUST_NOT_EXPORT"], genome: "PRIVATE_GENOME")

    func testSourceIsDisplayOnlyAndIdentifierIsOptIn() throws {
        let source = WalletPassSource(card: card, title: "Test Card", includeIdentifier: false)
        let data = try source.jsonData()
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["formatVersion"] as? Int, 1)
        XCTAssertNil(json["nfc"])
        XCTAssertNil(json["barcodes"])
        XCTAssertNil(json["barcode"])
        XCTAssertNil(json["webServiceURL"])
        XCTAssertNil(json["authenticationToken"])
        XCTAssertNil(json["passTypeIdentifier"])
        XCTAssertNil(json["teamIdentifier"])
        let text = String(decoding: data, as: UTF8.self)
        for privateValue in ["01020304050607", "MUST_NOT_EXPORT", "PRIVATE_GENOME"] {
            XCTAssertFalse(text.contains(privateValue))
        }
        XCTAssertEqual(source.generic.headerFields.first?.value, "DISPLAY ONLY")
        XCTAssertTrue(text.contains("does not emulate"))
    }

    func testIdentifierCanBeExplicitlyIncludedAndSourceRoundTrips() throws {
        let source = WalletPassSource(card: card, title: "Test Card", includeIdentifier: true)
        XCTAssertEqual(source.generic.auxiliaryFields.first?.value, card.uidHex)
        XCTAssertEqual(try JSONDecoder().decode(WalletPassSource.self, from: source.jsonData()), source)
    }

    func testPassIdentityIsStableButNotTheCardIdentifier() {
        let first = WalletPassSource(card: card, title: "One", includeIdentifier: false)
        let second = WalletPassSource(card: card, title: "Two", includeIdentifier: true)
        XCTAssertEqual(first.serialNumber, second.serialNumber)
        XCTAssertFalse(first.serialNumber.contains(card.uidHex!))
        XCTAssertTrue(first.serialNumber.hasPrefix("nfccard-"))
    }

    func testDisplayTitlesAreBoundedAndEmptyNamesHaveFallback() {
        XCTAssertEqual(WalletPassSource.displayTitle(" \n\t "), "NFC Card")
        XCTAssertEqual(WalletPassSource.displayTitle("Unknown Card"), "NFC Card")
        XCTAssertEqual(WalletPassSource.displayTitle(" بطاقة شخصية "), "بطاقة شخصية")
        XCTAssertEqual(WalletPassSource.displayTitle(String(repeating: "x", count: 200)).count, 80)
    }

    func testImporterRejectsJSONRemoteURLsAndInvalidSizes() {
        XCTAssertNoThrow(try WalletPassFile.validateFileName(URL(fileURLWithPath: "/tmp/test.PKPASS")))
        XCTAssertThrowsError(try WalletPassFile.validateFileName(URL(fileURLWithPath: "/tmp/source.json")))
        XCTAssertThrowsError(try WalletPassFile.validateFileName(URL(string: "https://example.com/pass.pkpass")!))
        XCTAssertThrowsError(try WalletPassFile.validateByteCount(0))
        XCTAssertThrowsError(try WalletPassFile.validateByteCount(WalletPassFile.maximumBytes + 1))
        XCTAssertNoThrow(try WalletPassFile.validateByteCount(WalletPassFile.maximumBytes))
    }

    func testFileReaderLoadsLocalDataButRejectsDirectoryAndOversizeFile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("test.pkpass")
        let bytes = Data("not a signed pass; PassKit validates it separately".utf8)
        try bytes.write(to: file)
        let loaded = try await WalletPassFile.load(file)
        XCTAssertEqual(loaded, bytes)
        try Data(repeating: 0, count: WalletPassFile.maximumBytes + 1).write(to: file)
        do { _ = try await WalletPassFile.load(file); XCTFail("Oversize file accepted") }
        catch { XCTAssertTrue(error is WalletPassFile.ImportError) }
        let directory = root.appendingPathComponent("folder.pkpass")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do { _ = try await WalletPassFile.load(directory); XCTFail("Directory accepted") }
        catch { XCTAssertTrue(error is WalletPassFile.ImportError) }
    }
}

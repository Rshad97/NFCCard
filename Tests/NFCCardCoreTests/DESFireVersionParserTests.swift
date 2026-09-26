import XCTest
@testable import NFCCardCore

final class DESFireVersionParserTests: XCTestCase {
    func testParsesThreeFrameGetVersionResponseConservatively() {
        let payload = Data([
            0x04, 0x01, 0x01, 0x01, 0x00, 0x18, 0x05,
            0x04, 0x01, 0x01, 0x01, 0x00, 0x18, 0x05,
            0x04, 0x2B, 0x58, 0x32, 0xB2, 0x6B, 0x80,
            0x01, 0x02, 0x03, 0x04, 0x05,
            0x12, 0x26
        ])

        let result = DESFireVersionParser.parse(
            payload: payload,
            statusWords: [0x91AF, 0x91AF, 0x9100],
            observedUIDHex: "042B5832B26B80"
        )

        XCTAssertTrue(result.recognized)
        XCTAssertEqual(result.summary, "DESFire-compatible GetVersion response")
        XCTAssertEqual(result.statusWords, ["91AF", "91AF", "9100"])
        XCTAssertEqual(result.details["Vendor"], "NXP (0x04)")
        XCTAssertEqual(result.details["Hardware Version"], "1.0")
        XCTAssertEqual(result.details["Software Version"], "1.0")
        XCTAssertEqual(result.details["Storage"], "4096 bytes (code 0x18)")
        XCTAssertEqual(result.details["Version UID"], "042B5832B26B80")
        XCTAssertEqual(result.details["UID Match"], "Yes")
        XCTAssertEqual(result.rawResponseHex, payload.hexString)
    }

    func testUnsupportedStatusDoesNotClaimDESFire() {
        let result = DESFireVersionParser.parse(
            payload: Data(),
            statusWords: [0x6D00],
            observedUIDHex: "01020304"
        )

        XCTAssertFalse(result.recognized)
        XCTAssertEqual(result.summary, "DESFire GetVersion not confirmed")
        XCTAssertEqual(result.statusText, "6D00")
        XCTAssertTrue(result.details.isEmpty)
    }

    func testIncompleteContinuationDoesNotClaimDESFire() {
        let payload = Data(repeating: 0x00, count: 14)
        let result = DESFireVersionParser.parse(
            payload: payload,
            statusWords: [0x91AF, 0x9100],
            observedUIDHex: nil
        )

        XCTAssertTrue(result.recognized)
        XCTAssertEqual(result.statusText, "91AF → 9100")
    }

    func testUnexpectedIntermediateStatusDoesNotClaimDESFire() {
        let payload = Data(repeating: 0x00, count: 14)
        let result = DESFireVersionParser.parse(
            payload: payload,
            statusWords: [0x9000, 0x9100],
            observedUIDHex: nil
        )

        XCTAssertFalse(result.recognized)
    }
}

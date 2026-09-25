import XCTest

final class NFCCardUITests: XCTestCase {
    func testWalletImportIsAvailableWithoutAnActiveScan() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Wallet"].tap()
        XCTAssertTrue(app.buttons["wallet.import"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["wallet.access-limitation"].exists)
        // An Add to Wallet button must not appear before a signed pass exists.
        XCTAssertFalse(app.buttons["wallet.add-pass"].exists)
    }

    func testSavedSnapshotHasWalletPreviewWithoutExposingUIDByDefault() {
        let app = XCUIApplication()
        app.launchArguments += ["--ui-test-wallet"]
        app.launch()
        app.tabBars.buttons["Library"].tap()
        let card = app.staticTexts["Wallet Test Card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let wallet = app.buttons["card.wallet"]
        XCTAssertTrue(wallet.waitForExistence(timeout: 5))
        wallet.tap()
        XCTAssertTrue(app.staticTexts["DISPLAY ONLY"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Not an access credential"].exists)
        XCTAssertFalse(app.staticTexts["01020304050607"].exists)
        let toggle = app.switches["wallet.include-identifier"]
        XCTAssertTrue(toggle.exists)
        toggle.tap()
        XCTAssertTrue(app.staticTexts["01020304050607"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testUnavailableNFCCanBeRetriedWithoutFreezingNavigation() {
        let app = XCUIApplication()
        app.launch()
        let scan = app.buttons["scan.standard"]
        XCTAssertTrue(scan.waitForExistence(timeout: 10))
        for _ in 0..<3 {
            scan.tap()
            let error = app.staticTexts["scan.error"]
            XCTAssertTrue(error.waitForExistence(timeout: 12))
            XCTAssertTrue(error.label.contains("not available"))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: scan)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            app.buttons["scan.dismiss-error"].tap()
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(scan.isEnabled)
    }
}

import XCTest

final class NFCCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            let app = XCUIApplication()
            attachScreenshot(app, name: "Failure screenshot")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Accessibility hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
    }

    func testNDEFWriteIsDisabledWithoutInspectionAndReadCanRetry() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["ndef.open"].tap()
        let read = app.buttons["ndef.read"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        let review = app.buttons["ndef.review"]
        XCTAssertTrue(review.exists)
        XCTAssertFalse(review.isEnabled)
        let field = app.textViews["ndef.content"].exists ? app.textViews["ndef.content"] : app.textFields["ndef.content"]
        XCTAssertTrue(field.exists)
        field.tap()
        field.typeText("Safe NDEF test draft")
        app.buttons["ndef.done"].tap()
        XCTAssertFalse(review.isEnabled, "A valid draft alone must never enable writing")
        for _ in 0..<2 {
            read.tap()
            XCTAssertTrue(app.staticTexts["ndef.error"].waitForExistence(timeout: 12))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: read)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            XCTAssertFalse(review.isEnabled)
        }
        attachScreenshot(app, name: "NDEF read failure remains retryable; writing disabled")
    }

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
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(toggle.isHittable)
        // SwiftUI exposes the whole labelled row as a Switch. Its centre is
        // the label, not the UISwitch. Target the trailing control in this
        // English-language test, relative to the row rather than screen pixels.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["01020304050607"].waitForExistence(timeout: 5))
        attachScreenshot(app, name: "Wallet preview with identifier enabled")

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 5), .completed)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.staticTexts["01020304050607"])
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed)
        attachScreenshot(app, name: "Wallet preview with identifier hidden")
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
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

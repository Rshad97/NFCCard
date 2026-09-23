import XCTest

final class NFCCardUITests: XCTestCase {
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
            XCTAssertTrue(scan.isEnabled)
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

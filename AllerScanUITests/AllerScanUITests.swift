import XCTest

final class AllerScanUITests: XCTestCase {
    func testOnboardingCanCreateProfile() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 5))

        let profileField = app.textFields["Profile name"]
        XCTAssertTrue(profileField.exists)
        profileField.tap()
        profileField.typeText("Taylor")

        app.buttons["Milk"].tap()
        app.buttons["Save Profile"].tap()

        XCTAssertTrue(app.tabBars.buttons["Scan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["History"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}

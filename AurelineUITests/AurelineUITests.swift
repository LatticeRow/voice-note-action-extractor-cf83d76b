import XCTest

final class AurelineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigationShellInteractions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.buttons["inbox.openCapture"].waitForExistence(timeout: 5))
        app.buttons["inbox.openCapture"].tap()

        XCTAssertTrue(app.buttons["capture.recordDraft"].waitForExistence(timeout: 5))
        app.buttons["capture.recordDraft"].tap()
        app.buttons["capture.importDraft"].tap()

        app.tabBars.buttons["Inbox"].tap()

        let memoButton = app.buttons["memoRow.Project follow-up"]
        XCTAssertTrue(memoButton.waitForExistence(timeout: 5))
        memoButton.tap()

        XCTAssertTrue(app.buttons["detail.addTranscript"].waitForExistence(timeout: 5))
        app.buttons["detail.addTranscript"].tap()
        app.buttons["detail.addReview"].tap()

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.refresh"].waitForExistence(timeout: 5))
        app.buttons["settings.refresh"].tap()
    }
}

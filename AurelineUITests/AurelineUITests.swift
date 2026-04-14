import XCTest

final class AurelineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureFlowInteractions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.buttons["inbox.openCapture"].waitForExistence(timeout: 5))
        app.buttons["inbox.openCapture"].tap()

        XCTAssertTrue(app.buttons["capture.startRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.startRecording"].tap()

        XCTAssertTrue(app.buttons["capture.saveRecording"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["capture.discardRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.discardRecording"].tap()

        XCTAssertTrue(app.buttons["capture.startRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.startRecording"].tap()
        app.buttons["capture.saveRecording"].tap()

        XCTAssertTrue(app.buttons["detail.addTranscript"].waitForExistence(timeout: 5))
        app.buttons["detail.addTranscript"].tap()
        app.buttons["detail.addReview"].tap()

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        app.tabBars.buttons["Capture"].tap()
        XCTAssertTrue(app.buttons["capture.importFile"].waitForExistence(timeout: 5))
        app.buttons["capture.importFile"].tap()

        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        }

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.refresh"].waitForExistence(timeout: 5))
        app.buttons["settings.refresh"].tap()
    }
}

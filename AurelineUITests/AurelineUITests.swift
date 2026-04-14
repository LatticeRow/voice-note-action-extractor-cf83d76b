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
        XCTAssertTrue(app.staticTexts["Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."].waitForExistence(timeout: 5))
        app.buttons["detail.extractActions"].tap()

        XCTAssertTrue(app.switches["extraction.item.0.toggle"].waitForExistence(timeout: 5))
        app.switches["extraction.item.0.toggle"].tap()

        let titleField = app.textFields["extraction.item.0.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(" updated")

        let contactField = app.textFields["extraction.item.0.contact"]
        XCTAssertTrue(contactField.waitForExistence(timeout: 5))
        contactField.tap()
        contactField.typeText(" Lee")

        let dateToggle = app.buttons["extraction.item.0.dateToggle"]
        XCTAssertTrue(dateToggle.waitForExistence(timeout: 5))
        dateToggle.tap()
        XCTAssertTrue(app.datePickers["extraction.item.0.datePicker"].waitForExistence(timeout: 5))
        app.datePickers["extraction.item.0.datePicker"].tap()

        let clearDate = app.buttons["extraction.item.0.clearDate"]
        XCTAssertTrue(clearDate.waitForExistence(timeout: 5))
        clearDate.tap()

        XCTAssertTrue(app.buttons["detail.saveReview"].waitForExistence(timeout: 5))
        app.buttons["detail.saveReview"].tap()

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

    @MainActor
    func testTranscriptionFailureShowsExplicitMessage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnDeviceUnavailable"]
        app.launch()

        XCTAssertTrue(app.buttons["inbox.openCapture"].waitForExistence(timeout: 5))
        app.buttons["inbox.openCapture"].tap()
        XCTAssertTrue(app.buttons["capture.startRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.startRecording"].tap()
        XCTAssertTrue(app.buttons["capture.saveRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.saveRecording"].tap()

        XCTAssertTrue(app.buttons["detail.addTranscript"].waitForExistence(timeout: 5))
        app.buttons["detail.addTranscript"].tap()

        XCTAssertTrue(app.staticTexts["Offline transcription for English (United States) isn’t available on this device."].waitForExistence(timeout: 5))
    }
}

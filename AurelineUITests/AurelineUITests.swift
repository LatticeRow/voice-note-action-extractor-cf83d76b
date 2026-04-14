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

        tapWhenReady(app.buttons["inbox.reviewAccess"])
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["settings.permission.microphone.action"])
        tapWhenReady(app.buttons["settings.permission.speech.action"])
        tapWhenReady(app.buttons["settings.permission.reminders.action"])
        tapWhenReady(app.buttons["settings.refresh"])

        app.tabBars.buttons["Inbox"].tap()
        tapWhenReady(app.buttons["inbox.openCapture"])

        tapWhenReady(app.buttons["capture.startRecording"])
        XCTAssertTrue(app.buttons["capture.saveRecording"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["capture.discardRecording"].waitForExistence(timeout: 5))
        app.buttons["capture.discardRecording"].tap()

        tapWhenReady(app.buttons["capture.startRecording"])
        tapWhenReady(app.buttons["capture.saveRecording"])

        tapWhenReady(app.buttons["detail.addTranscript"])
        XCTAssertTrue(app.staticTexts["Call Jordan tomorrow about the lighting quote. Send the revised site plan before Friday."].waitForExistence(timeout: 5))
        tapWhenReady(app.buttons["detail.extractActions"])

        tapWhenReady(app.switches["extraction.item.0.toggle"])

        let titleField = app.textFields["extraction.item.0.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(" updated")

        let contactField = app.textFields["extraction.item.0.contact"]
        XCTAssertTrue(contactField.waitForExistence(timeout: 5))
        contactField.tap()
        contactField.typeText(" Lee")

        tapWhenReady(app.buttons["extraction.item.0.dateToggle"])
        XCTAssertTrue(app.datePickers["extraction.item.0.datePicker"].waitForExistence(timeout: 5))
        app.datePickers["extraction.item.0.datePicker"].tap()
        tapWhenReady(app.buttons["extraction.item.0.clearDate"])

        let mentionField = app.textFields["extraction.mention.0.text"]
        XCTAssertTrue(mentionField.waitForExistence(timeout: 5))
        mentionField.tap()
        mentionField.typeText(" updated")

        tapWhenReady(app.buttons["extraction.mention.1.delete"])
        tapWhenReady(app.buttons["extraction.item.1.delete"])
        tapWhenReady(app.buttons["detail.saveReview"])

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        app.tabBars.buttons["Capture"].tap()
        tapWhenReady(app.buttons["capture.importFile"])

        let cancelButton = app.buttons["Cancel"].firstMatch
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        }

        app.tabBars.buttons["Settings"].tap()
        tapWhenReady(app.buttons["settings.refresh"])
    }

    @MainActor
    func testSeededInboxSearchAndStateNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeedInbox"]
        app.launch()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Client")

        tapWhenReady(app.buttons["memoRow.Client estimate"])
        XCTAssertTrue(app.staticTexts["Call Jordan tomorrow about the lighting quote."].waitForExistence(timeout: 5))

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.tap()

        clearSearchText(in: searchField)
        searchField.typeText("Service")
        tapWhenReady(app.buttons["memoRow.Service call"])
        XCTAssertTrue(app.staticTexts["Transcript unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Offline transcription isn’t available on this device."].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        clearSearchText(in: searchField)
        searchField.typeText("Morning")
        tapWhenReady(app.buttons["memoRow.Morning brief"])
        XCTAssertTrue(app.staticTexts["No transcript yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No review yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTranscriptionFailureShowsExplicitMessage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingOnDeviceUnavailable"]
        app.launch()

        tapWhenReady(app.buttons["inbox.openCapture"])
        tapWhenReady(app.buttons["capture.startRecording"])
        tapWhenReady(app.buttons["capture.saveRecording"])
        tapWhenReady(app.buttons["detail.addTranscript"])

        XCTAssertTrue(
            app.staticTexts["Offline transcription for English (United States) isn’t available on this device."].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testExportFlowExercisesRemindersAndShareSheet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestingSeedInbox"]
        app.launch()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Client")

        tapWhenReady(app.buttons["memoRow.Client estimate"])
        tapWhenReady(app.buttons["detail.exportReminders"])

        tapWhenReady(app.buttons["export.reminders.list.1"])
        tapWhenReady(app.buttons["export.reminders.list.0"])
        tapWhenReady(app.buttons["export.reminders.cancel"])

        tapWhenReady(app.buttons["detail.exportReminders"])
        tapWhenReady(app.buttons["export.reminders.list.1"])
        tapWhenReady(app.buttons["export.reminders.confirm"])

        tapWhenReady(app.buttons["detail.shareSummary"])
    }

    private func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        element.tap()
    }

    private func clearSearchText(in field: XCUIElement) {
        guard let currentValue = field.value as? String, !currentValue.isEmpty else { return }
        field.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        field.typeText(deleteString)
    }
}

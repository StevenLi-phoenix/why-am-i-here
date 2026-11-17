import XCTest

/// Drives the main flows against an in-memory store (`-uiTesting`).
final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(_ arguments: String...) {
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Opens a deep link in the running app. `XCUIApplication.open` would relaunch it and drop the in-memory data.
    private func openDeepLink(_ string: String) {
        XCUIDevice.shared.system.open(URL(string: string)!)
    }

    private func waitFor(_ element: XCUIElement, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), message, file: file, line: line)
    }

    func testEmptyStateOffersSetup() {
        launch()
        waitFor(app.staticTexts["Today"], "Today tab is the first screen")
        XCTAssertTrue(app.staticTexts["No check-ins yet"].exists)
        XCTAssertFalse(element("lastCheckIn").exists)
        element("setupButton").tap()
        waitFor(app.staticTexts["Ask when it opens"], "setup guide opens from the Today card")
    }

    func testCheckInRecordsReasonAndShowsOnToday() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        waitFor(app.staticTexts["Why Are You Here?"], "Intent Check appears for a watched app")
        XCTAssertTrue(app.staticTexts["Opening Instagram · Pickup #1 today"].exists)

        let continueButton = element("continueButton")
        XCTAssertFalse(continueButton.isEnabled, "Continue needs a reason first")
        element("reason.messages").tap()
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        // The simulator has no Instagram, so the app falls back to telling the user to switch back.
        waitFor(element("notice"), "handoff fallback notice")
        waitFor(element("lastCheckIn"), "Today shows the last check-in")
        XCTAssertTrue(element("lastCheckIn").label.hasPrefix("Last check-in: Messages"))
        XCTAssertTrue(element("intentionalPercent").label.hasPrefix("100%"))
        XCTAssertTrue(element("stat.Pickups").label.contains("1"))
        XCTAssertTrue(element("stat.Mindless").label.contains("0"))
    }

    func testSkipCountsAsMindless() {
        launch("-openURL", "whyamihere://ask?app=tiktok")
        waitFor(app.staticTexts["Opening TikTok · Pickup #1 today"], "Intent Check names the app")
        element("skipButton").tap()
        waitFor(element("lastCheckIn"), "skip is recorded")
        XCTAssertTrue(element("lastCheckIn").label.hasPrefix("Last check-in: Skipped"))
        XCTAssertTrue(element("intentionalPercent").label.hasPrefix("0%"))
        XCTAssertTrue(element("stat.Mindless").label.contains("1"))
    }

    func testReminderDoneEndsSessionAndReturnsToToday() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        waitFor(element("reason.justBored"), "Intent Check appears")
        element("reason.justBored").tap()
        element("continueButton").tap()
        waitFor(element("lastCheckIn"), "check-in recorded")

        openDeepLink("whyamihere://reminder")
        waitFor(element("reminderTitle"), "Gentle Reminder appears for the running session")
        XCTAssertEqual(element("reminderTitle").label, "Still here for “Just Bored”?")
        XCTAssertTrue(app.staticTexts["on Instagram so far."].exists)
        element("doneButton").tap()

        waitFor(app.staticTexts["Today"], "back on Today after Done")
        XCTAssertFalse(element("reminderTitle").exists)
        // The session is over, so there is nothing left to remind about.
        openDeepLink("whyamihere://reminder")
        XCTAssertFalse(element("reminderTitle").waitForExistence(timeout: 2))
    }

    func testUnwatchedAppIsNotAskedAbout() {
        launch("-openURL", "whyamihere://ask?app=youtube")
        waitFor(app.staticTexts["Today"], "app launches")
        XCTAssertFalse(app.staticTexts["Why Are You Here?"].waitForExistence(timeout: 2))
    }

    func testDemoDataMatchesPrototypeNumbers() {
        launch("-demoData")
        waitFor(element("intentionalPercent"), "Today loads")
        XCTAssertTrue(element("intentionalPercent").label.hasPrefix("62%"))
        XCTAssertTrue(element("stat.Screen Time").label.contains("2h 41m"))
        XCTAssertTrue(element("stat.Pickups").label.contains("37"))
        XCTAssertTrue(element("stat.Mindless").label.contains("14"))
        XCTAssertTrue(element("lastCheckIn").label.hasPrefix("Last check-in: Messages"))

        element("weekCard").tap()
        waitFor(app.staticTexts["Reflection"], "week card opens Reflection")
        XCTAssertTrue(app.staticTexts["Daily Pickups"].exists)
        XCTAssertTrue(element("insight").label.contains("out of boredom"))

        element("adjustReminders").tap()
        waitFor(app.staticTexts["Settings"], "Adjust Reminders opens Settings")
    }

    func testSettingsControls() {
        launch()
        app.tabBars.buttons["Settings"].tap()
        waitFor(element("remindMinutes"), "Settings loads")
        XCTAssertEqual(element("remindMinutes").label, "15")
        app.buttons["remindStepper-Increment"].tap()
        XCTAssertEqual(element("remindMinutes").label, "20")
        app.buttons["remindStepper-Decrement"].tap()
        app.buttons["remindStepper-Decrement"].tap()
        XCTAssertEqual(element("remindMinutes").label, "10")

        element("frequency.afterThirtyMinutesAway").tap()
        XCTAssertTrue(element("frequency.afterThirtyMinutesAway").isSelected)
        XCTAssertFalse(element("frequency.everyOpen").isSelected)

        XCTAssertTrue(app.staticTexts["From 10 PM to 7 AM."].exists)

        element("watchedApps").tap()
        waitFor(element("app.youtube"), "Watched Apps list")
        XCTAssertTrue(element("app.instagram").isSelected)
        XCTAssertFalse(element("app.youtube").isSelected)
        element("app.youtube").tap()
        XCTAssertTrue(element("app.youtube").isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        // The row exposes its summary as part of one combined element, as label or value depending on the OS.
        let summary = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@",
                                  "Instagram, TikTok + 1", "Instagram, TikTok + 1")
        waitFor(app.descendants(matching: .any).matching(summary).firstMatch, "summary reflects the new watched app")
    }

    func testPreviewWalksThroughBothScreensWithoutRecording() {
        launch("-openURL", "whyamihere://preview")
        waitFor(app.staticTexts["Why Are You Here?"], "preview shows the Intent Check")
        element("reason.workOrSchool").tap()
        element("continueButton").tap()
        waitFor(element("reminderTitle"), "preview continues to the reminder")
        XCTAssertEqual(element("reminderTitle").label, "Still here for “Work or School”?")
        element("keepGoingButton").tap()
        waitFor(app.staticTexts["No check-ins yet"], "nothing was recorded")
    }
}

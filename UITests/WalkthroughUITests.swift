import XCTest

/// Cognitive-walkthrough capture for usability work: plays each usability-test task the way a first-time
/// user would and attaches a screenshot at every step. Skipped unless `WAIH_WALKTHROUGH=1`
/// (run through `scripts/walkthrough.sh`, which also exports the screenshots).
final class WalkthroughUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["WAIH_WALKTHROUGH"] == "1",
                          "walkthrough capture runs only from scripts/walkthrough.sh")
        continueAfterFailure = true
        app = XCUIApplication()
    }

    private func launch(_ arguments: String...) {
        app.launchArguments = ["-uiTesting"] + arguments
        app.launch()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func shot(_ name: String) {
        // Let animations settle so the frame matches what a participant would see.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// T1: first run, get the app ready to ask before Instagram.
    func testT1FirstRunSetup() {
        launch()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8))
        shot("T1-1 first launch")
        element("setupButton").tap()
        XCTAssertTrue(app.staticTexts["Ask when it opens"].waitForExistence(timeout: 5))
        shot("T1-2 setup guide")
        app.swipeUp()
        shot("T1-3 setup guide bottom")
        app.buttons["Done"].tap()
        app.tabBars.buttons["Settings"].tap()
        element("watchedApps").tap()
        shot("T1-4 watched apps")
    }

    /// T1, last step: after the first open through the automation, does the app show that setup worked?
    func testT1SetupStatusAfterFirstOpen() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        XCTAssertTrue(element("skipButton").waitForExistence(timeout: 8))
        element("skipButton").tap()
        app.tabBars.buttons["Settings"].tap()
        element("watchedApps").tap()
        XCTAssertTrue(element("app.instagram").waitForExistence(timeout: 5))
        shot("T1-5 watched apps after first open")
        if element("setupGuide").exists {
            element("setupGuide").tap()
            shot("T1-6 setup guide after first open")
        }
    }

    /// T2: a purposeful pickup (replying to a friend on Instagram).
    func testT2PurposefulPickup() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        XCTAssertTrue(app.staticTexts["Why Are You Here?"].waitForExistence(timeout: 8))
        shot("T2-1 intent check")
        element("reason.messages").tap()
        shot("T2-2 reason selected")
        element("continueButton").tap()
        shot("T2-3 after continue")
    }

    /// T3: a habit pickup where the participant decides not to scroll after all (storyboard ending).
    func testT3HabitPickupChangeMind() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        XCTAssertTrue(app.staticTexts["Why Are You Here?"].waitForExistence(timeout: 8))
        shot("T3-1 intent check")
        if element("neverMindButton").exists {
            element("neverMindButton").tap()
        } else {
            element("skipButton").tap()
        }
        shot("T3-2 after leaving")
    }

    /// T4: a reason that is not on the list, with a note.
    func testT4OtherReason() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        XCTAssertTrue(app.staticTexts["Why Are You Here?"].waitForExistence(timeout: 8))
        element("reason.other").tap()
        shot("T4-1 other prompt")
        app.textFields.firstMatch.typeText("Party time")
        app.alerts.buttons["OK"].tap()
        shot("T4-2 other selected")
        element("continueButton").tap()
        shot("T4-3 after continue")
    }

    /// T5: the reminder after staying a while, then stopping.
    func testT5ReminderDone() {
        launch("-openURL", "whyamihere://ask?app=instagram")
        XCTAssertTrue(element("reason.justBored").waitForExistence(timeout: 8))
        element("reason.justBored").tap()
        element("continueButton").tap()
        XCTAssertTrue(element("lastCheckIn").waitForExistence(timeout: 8))
        XCUIDevice.shared.system.open(URL(string: "whyamihere://reminder")!)
        XCTAssertTrue(element("reminderTitle").waitForExistence(timeout: 8))
        shot("T5-1 reminder")
        element("doneButton").tap()
        shot("T5-2 after done")
    }

    /// T6: reading the week (sample history).
    func testT6ReadTheWeek() {
        launch("-demoData")
        XCTAssertTrue(element("intentionalPercent").waitForExistence(timeout: 8))
        shot("T6-1 today with history")
        app.swipeUp()
        shot("T6-2 today bottom")
        element("weekCard").tap()
        XCTAssertTrue(app.staticTexts["Daily Pickups"].waitForExistence(timeout: 5))
        shot("T6-3 reflection")
        if element("day.0").exists {
            element("day.0").tap()
            shot("T6-5 reflection first day selected")
        }
        app.swipeUp()
        shot("T6-4 reflection bottom")
    }

    /// T7–T9: asking less often, quiet hours, a later reminder, watching another app.
    func testT7to9Settings() {
        launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(element("remindMinutes").waitForExistence(timeout: 8))
        shot("T7-1 settings")
        element("frequency.afterThirtyMinutesAway").tap()
        shot("T7-2 frequency changed")
        app.swipeUp()
        shot("T8-1 settings bottom")
        if element("quietToggle").exists {
            element("quietToggle").switches.firstMatch.tap()
            if element("quietStart").waitForExistence(timeout: 3) {
                element("quietStart").tap()
                shot("T8-2 quiet hours start menu")
                let elevenPM = app.buttons["11 PM"]
                if elevenPM.waitForExistence(timeout: 3) { elevenPM.tap() }
                element("quietEnd").tap()
                let eightAM = app.buttons["8 AM"]
                if eightAM.waitForExistence(timeout: 3) { eightAM.tap() }
                shot("T8-3 quiet hours set")
            }
        }
        app.swipeDown()
        app.swipeDown()
        element("watchedApps").tap()
        XCTAssertTrue(element("app.youtube").waitForExistence(timeout: 5))
        element("app.youtube").tap()
        shot("T9-1 youtube watched")
        app.swipeUp()
        shot("T9-2 watched apps bottom")
        element("addApp").tap()
        shot("T9-3 add app sheet")
    }

    /// Try a Check-In from the setup screens (no data recorded).
    func testPreviewFlow() {
        launch("-openURL", "whyamihere://preview")
        XCTAssertTrue(app.staticTexts["Why Are You Here?"].waitForExistence(timeout: 8))
        element("reason.workOrSchool").tap()
        element("continueButton").tap()
        XCTAssertTrue(element("reminderTitle").waitForExistence(timeout: 5))
        shot("P-1 preview reminder")
        element("keepGoingButton").tap()
        shot("P-2 after preview")
    }
}

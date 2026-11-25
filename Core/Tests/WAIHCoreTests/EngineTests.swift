import XCTest
@testable import WAIHCore

@MainActor
final class EngineTests: XCTestCase {
    func testEveryOpenPromptsAndNumbersPickups() throws {
        let h = try Harness()
        XCTAssertEqual(h.engine.appOpened(Harness.instagram).pickupNumber, 1)
        h.advance(minutes: 1)
        XCTAssertEqual(h.engine.appOpened(Harness.tiktok).pickupNumber, 2)
    }

    func testEveryThirdOpenAsksOnFirstFourthSeventh() throws {
        let h = try Harness { $0.frequency = .everyThirdOpen }
        var asked: [Int] = []
        for open in 1...7 {
            if h.open() != nil { asked.append(open) }
            h.engine.appClosed(appID: "instagram")
            h.advance(minutes: 2)
        }
        XCTAssertEqual(asked, [1, 4, 7])
        XCTAssertEqual(h.store.totalCount, 7, "opens that are not asked about still count as pickups")
    }

    func testEveryThirdOpenCountsPerAppAndResetsEachDay() throws {
        let h = try Harness { $0.frequency = .everyThirdOpen }
        XCTAssertNotNil(h.open(Harness.instagram))
        h.advance(minutes: 1)
        XCTAssertNotNil(h.open(Harness.tiktok), "TikTok's first open of the day asks too")
        h.advance(minutes: 1)
        XCTAssertNil(h.open(Harness.instagram))
        h.clock = date(4, 8)
        XCTAssertNotNil(h.open(Harness.instagram), "first open of a new day asks")
    }

    func testAfterThirtyMinutesAway() throws {
        let h = try Harness { $0.frequency = .afterThirtyMinutesAway }
        let first = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: first, reason: .messages)
        h.advance(minutes: 5)
        h.engine.appClosed(appID: "instagram")
        h.advance(minutes: 29)
        XCTAssertNil(h.open(), "29 minutes after closing is too soon")
        h.advance(minutes: 1)
        h.engine.appClosed(appID: "instagram")
        h.advance(minutes: 31)
        XCTAssertNotNil(h.open())
    }

    func testNeverMindRecordsPickupWithoutSessionOrReminders() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.engine.changeMind(pickupID: id)
        let record = try XCTUnwrap(h.store.pickup(id: id)?.record)
        XCTAssertTrue(record.changedMind)
        XCTAssertFalse(record.isMindless, "deciding not to go in is not a mindless pickup")
        XCTAssertFalse(record.isIntentional)
        XCTAssertEqual(record.duration(now: h.clock), 0)
        XCTAssertTrue(h.store.activeSessions().isEmpty)
        XCTAssertTrue(h.reminders.active.isEmpty)
        XCTAssertEqual(Stats.lastCheckIn(h.store.lastCheckIn()?.record)?.label, "Changed Your Mind")

        // The next open is a fresh pickup that asks again.
        h.advance(minutes: 3)
        XCTAssertNotNil(h.open())
        XCTAssertEqual(h.store.totalCount, 2)
    }

    func testAskDisabledStillRecordsPickupAndStartsSession() throws {
        let h = try Harness { $0.askBeforeWatchedApps = false }
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.askDisabled))
        let active = h.store.activeSessions(appID: "instagram")
        XCTAssertEqual(active.count, 1)
        XCTAssertFalse(active[0].prompted)
        XCTAssertEqual(h.reminders.active.first?.title, "Still on Instagram?")
    }

    func testUnwatchedAppIsIgnored() throws {
        let h = try Harness { $0.watchedAppIDs = ["tiktok"] }
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.notWatched))
        XCTAssertEqual(h.store.totalCount, 0)
    }

    func testQuietHoursCrossMidnight() throws {
        let h = try Harness(start: date(3, 23)) { $0.pauseDuringQuietHours = true }
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.quietHours))
        h.engine.appClosed(appID: "instagram")
        h.clock = date(4, 6, 59)
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.quietHours))
        h.engine.appClosed(appID: "instagram")
        h.clock = date(4, 7, 0)
        XCTAssertNotNil(h.open())
    }

    func testQuietHoursOffByDefault() throws {
        let h = try Harness(start: date(3, 23))
        XCTAssertNotNil(h.open())
    }

    func testContinueStartsSessionAndHandoffIsNotAskedAgain() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.advance(minutes: 0.2)
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.engine.noteHandoff(appID: "instagram")
        h.advance(minutes: 0.05)
        // The automation fires again because we just opened Instagram ourselves.
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.handoff))
        XCTAssertEqual(h.store.totalCount, 1, "the handoff open is not a new pickup")
    }

    func testHandoffSurvivesRelaunchThroughActiveSession() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        // No noteHandoff: simulates the process restarting between Continue and the automation.
        h.advance(minutes: 0.1)
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.handoff))
        h.advance(minutes: 1)
        XCTAssertNotNil(h.open(), "outside the grace window a new open asks again")
    }

    func testSkipCountsAsMindless() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        let pickup = try XCTUnwrap(h.engine.completeCheckIn(pickupID: id, reason: nil))
        XCTAssertTrue(pickup.record.isMindless)
        XCTAssertTrue(pickup.skipped)
        XCTAssertNotNil(pickup.sessionStart)
    }

    func testOtherKeepsNoteAndReminderQuotesIt() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .other, note: "Reply to Sam")
        XCTAssertEqual(h.reminders.active.first?.title, "Still here for “Reply to Sam”?")
    }

    func testReminderPlanFiresEveryIntervalWithElapsedMinutes() throws {
        let h = try Harness { $0.remindAfterMinutes = 15 }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        let plan = try XCTUnwrap(h.reminders.active.first)
        XCTAssertEqual(plan.title, "Still here for “Messages”?")
        XCTAssertEqual(plan.fires.map(\.minutes), [15, 30, 45, 60])
        XCTAssertEqual(plan.fires.first?.date, h.clock.addingTimeInterval(15 * 60))
    }

    func testRemindersDisabledSchedulesNothing() throws {
        let h = try Harness { $0.remindInWatchedApps = false }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        XCTAssertTrue(h.reminders.scheduled.isEmpty)
    }

    func testRemindersSkipQuietHours() throws {
        let h = try Harness(start: date(3, 21, 40)) {
            $0.pauseDuringQuietHours = true
            $0.remindAfterMinutes = 15
        }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .justBored)
        // 21:55 fires; 22:10, 22:25 and 22:40 fall inside quiet hours.
        XCTAssertEqual(h.reminders.active.first?.fires.map(\.minutes), [15])
    }

    func testCloseEndsSessionAndCancelsReminders() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.advance(minutes: 7)
        h.engine.appClosed(appID: "instagram")
        let pickup = try XCTUnwrap(h.store.pickup(id: id))
        XCTAssertEqual(pickup.endedBy, .closed)
        XCTAssertEqual(pickup.record.duration(now: h.clock), 7 * 60, accuracy: 0.5)
        XCTAssertTrue(h.reminders.cancelled.contains(id))
        XCTAssertTrue(h.store.activeSessions().isEmpty)
    }

    func testDoneAfterCloseKeepsCloseTime() throws {
        let h = try Harness()
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.advance(minutes: 15)
        h.engine.appClosed(appID: "instagram") // the reminder brought our app forward
        h.advance(minutes: 1)
        h.engine.finish(pickupID: id)
        let pickup = try XCTUnwrap(h.store.pickup(id: id))
        XCTAssertEqual(pickup.endedBy, .done)
        XCTAssertEqual(pickup.record.duration(now: h.clock), 15 * 60, accuracy: 0.5)
    }

    func testKeepGoingResumesSessionAndReschedules() throws {
        let h = try Harness { $0.remindAfterMinutes = 15 }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.advance(minutes: 15)
        h.engine.appClosed(appID: "instagram")
        let pickup = try XCTUnwrap(h.engine.keepGoing(pickupID: id))
        XCTAssertNil(pickup.sessionEnd)
        XCTAssertEqual(pickup.keepGoingCount, 1)
        XCTAssertEqual(h.reminders.active.first?.fires.map(\.minutes), [30, 45, 60, 75])
        XCTAssertEqual(h.engine.appOpened(Harness.instagram), .passthrough(.handoff))
    }

    func testStaleSessionIsCappedWhenNextOpenArrives() throws {
        let h = try Harness { $0.remindAfterMinutes = 15 }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.advance(minutes: 120) // no "Is Closed" automation, so nothing ended the session
        XCTAssertNotNil(h.open())
        let stale = try XCTUnwrap(h.store.pickup(id: id))
        XCTAssertEqual(stale.endedBy, .stale)
        XCTAssertEqual(stale.record.duration(now: h.clock), 15 * 60, accuracy: 0.5)
    }

    func testRefreshRemindersAppliesNewInterval() throws {
        let h = try Harness { $0.remindAfterMinutes = 15 }
        let id = try XCTUnwrap(h.open())
        h.engine.completeCheckIn(pickupID: id, reason: .messages)
        h.advance(minutes: 12)
        h.engine.settings.remindAfterMinutes = 10
        h.engine.refreshReminders()
        XCTAssertEqual(h.reminders.active.first?.fires.map(\.minutes), [20, 30, 40])
        h.engine.settings.remindInWatchedApps = false
        h.engine.refreshReminders()
        XCTAssertEqual(h.reminders.cancelled.last, id)
    }
}

private extension OpenOutcome {
    var pickupNumber: Int? {
        if case .prompt(_, let number) = self { return number }
        return nil
    }
}

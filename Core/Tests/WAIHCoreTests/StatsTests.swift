import XCTest
@testable import WAIHCore

final class StatsTests: XCTestCase {
    private func record(_ reason: Reason?, day: Int = 3, hour: Int = 10, minute: Int = 0, app: String = "Instagram",
                        skipped: Bool = false, minutes: Double = 0, note: String? = nil) -> PickupRecord {
        let opened = date(day, hour, minute)
        return PickupRecord(appID: app.lowercased(), appName: app, openedAt: opened, reason: reason, note: note,
                            skipped: skipped, sessionStart: minutes > 0 ? opened : nil,
                            sessionEnd: minutes > 0 ? opened.addingTimeInterval(minutes * 60) : nil)
    }

    /// The prototype's Today screen: 37 pickups, 14 mindless, 62% intentional.
    func testDaySummaryMatchesPrototype() {
        var records: [PickupRecord] = []
        records += (0..<12).map { record(.messages, minute: $0) }
        records += (0..<9).map { record(.justBored, hour: 11, minute: $0) }
        records += (0..<7).map { record(.workOrSchool, hour: 12, minute: $0) }
        records += (0..<4).map { record(.lookSomethingUp, hour: 13, minute: $0) }
        records += (0..<5).map { record(nil, hour: 14, minute: $0, skipped: true) }
        records.append(record(.messages, day: 2)) // another day, ignored

        let summary = Stats.day(records: records, on: date(3), now: date(3, 22), calendar: testCalendar)
        XCTAssertEqual(summary.pickups, 37)
        XCTAssertEqual(summary.mindless, 14)
        XCTAssertEqual(summary.intentionalPercent, 62)
        XCTAssertEqual(summary.topReasons.map(\.reason), [.messages, .justBored, .workOrSchool])
        XCTAssertEqual(summary.topReasons.map(\.count), [12, 9, 7])
        XCTAssertEqual(summary.topReasons[0].barFraction, 1)
        XCTAssertEqual(summary.topReasons[1].barFraction, 0.75, accuracy: 0.001)
    }

    func testEmptyDayHasNoPercent() {
        let summary = Stats.day(records: [], on: date(3), now: date(3, 22), calendar: testCalendar)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertNil(summary.intentionalPercent)
        XCTAssertEqual(summary.screenTime, 0)
    }

    func testUnansweredPickupsDoNotCountEitherWay() {
        // Asked but left without answering, and let through without being asked.
        let abandoned = record(nil)
        var unprompted = record(nil, hour: 11, minutes: 5)
        unprompted.prompted = false
        let summary = Stats.day(records: [abandoned, unprompted, record(.messages, hour: 12)],
                                on: date(3), now: date(3, 22), calendar: testCalendar)
        XCTAssertEqual(summary.pickups, 3)
        XCTAssertEqual(summary.mindless, 0)
        XCTAssertEqual(summary.intentionalPercent, 100)
    }

    func testScreenTimeCountsRunningSessionUpToNow() {
        var running = record(.messages, hour: 21)
        running.sessionStart = date(3, 21)
        let summary = Stats.day(records: [record(.messages, minutes: 30), running],
                                on: date(3), now: date(3, 21, 12), calendar: testCalendar)
        XCTAssertEqual(summary.screenTime, 42 * 60, accuracy: 0.5)
    }

    func testTopReasonTiesKeepDisplayOrder() {
        let stats = Stats.topReasons([record(.justBored), record(.messages), record(.directions)], limit: 3)
        XCTAssertEqual(stats.map(\.reason), [.messages, .directions, .justBored])
        XCTAssertEqual(stats.map(\.percent), [33, 33, 33])
    }

    func testWeekSummary() {
        // Week of Mon Nov 3 – Sun Nov 9 2025; "now" is Wednesday.
        var records: [PickupRecord] = []
        records += (0..<10).map { record(.messages, day: 3, minute: $0, minutes: 6) }
        records += (0..<20).map { record(.justBored, day: 4, hour: 21, minute: $0, minutes: 6) }
        records += (0..<6).map { record(.workOrSchool, day: 5, minute: $0, minutes: 6) }
        // Last week: 40 pickups Mon–Wed, plus 50 later in the week that must not count yet.
        var previous: [PickupRecord] = []
        previous += (0..<40).map { record(.messages, day: 27 + $0 % 3, hour: 9 + $0 / 10) }.map {
            var r = $0
            r.openedAt = testCalendar.date(byAdding: .month, value: -1, to: r.openedAt)!
            return r
        }
        previous += (0..<50).map { _ in
            var r = record(.messages, day: 1)
            r.openedAt = date(1, 10)
            return r
        }

        let week = Stats.week(records: records, previous: previous, now: date(5, 18), calendar: testCalendar)
        XCTAssertEqual(Format.weekRange(week.interval, calendar: testCalendar), "Nov 3 – Nov 9")
        XCTAssertEqual(week.days.map(\.count), [10, 20, 6, 0, 0, 0, 0])
        XCTAssertEqual(week.days.map(\.letter), ["M", "T", "W", "T", "F", "S", "S"])
        XCTAssertEqual(week.days.map(\.isFuture), [false, false, false, true, true, true, true])
        XCTAssertEqual(week.pickups, 36)
        XCTAssertEqual(week.averagePerDay, 12, accuracy: 0.001)
        XCTAssertEqual(week.busiestIndex, 1)
        XCTAssertEqual(week.changePercent, -10) // 36 against 40 over the same three days
        XCTAssertEqual(week.screenTime, 36 * 6 * 60, accuracy: 0.5)
        XCTAssertEqual(week.topReasons.map(\.percent), [56, 28, 17])
        XCTAssertEqual(week.insight, "You opened Instagram out of boredom 20 times, mostly after 9 PM.")
    }

    func testWeekWithoutBaselineHasNoChange() {
        let week = Stats.week(records: [record(.messages)], previous: [], now: date(3, 18), calendar: testCalendar)
        XCTAssertNil(week.changePercent)
        XCTAssertEqual(week.busiestIndex, 0)
    }

    func testInsights() {
        XCTAssertEqual(Stats.insight([], calendar: testCalendar),
                       "Your week will take shape here after your first check-in.")
        XCTAssertEqual(Stats.insight([record(.justBored, hour: 9, app: "TikTok")], calendar: testCalendar),
                       "You opened TikTok out of boredom once, mostly in the morning.")
        let mixed = [record(.justBored, hour: 9), record(.justBored, hour: 14), record(.justBored, hour: 19),
                     record(.justBored, hour: 23)]
        XCTAssertEqual(Stats.insight(mixed, calendar: testCalendar), "You opened Instagram out of boredom 4 times.")
        XCTAssertEqual(Stats.insight([record(.messages), record(.directions)], calendar: testCalendar),
                       "2 pickups this week had a clear reason, and none were out of boredom.")
        XCTAssertEqual(Stats.insight([record(nil, skipped: true), record(nil, skipped: true), record(.messages)],
                                     calendar: testCalendar),
                       "You skipped the check-in 2 times this week. Naming a reason makes reminders more useful.")
    }

    func testLastCheckInLabels() {
        XCTAssertEqual(Stats.lastCheckIn(record(.messages))?.label, "Messages")
        XCTAssertEqual(Stats.lastCheckIn(record(.other, note: " Reply to Sam "))?.label, "Reply to Sam")
        XCTAssertEqual(Stats.lastCheckIn(record(.other))?.label, "Other")
        XCTAssertEqual(Stats.lastCheckIn(record(nil, skipped: true))?.label, "Skipped")
        XCTAssertNil(Stats.lastCheckIn(record(nil)))
        XCTAssertNil(Stats.lastCheckIn(nil))
    }
}

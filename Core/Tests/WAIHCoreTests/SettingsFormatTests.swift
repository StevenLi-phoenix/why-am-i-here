import XCTest
@testable import WAIHCore

final class SettingsFormatTests: XCTestCase {
    func testDefaultsMatchPrototype() {
        let settings = WAIHSettings()
        XCTAssertTrue(settings.askBeforeWatchedApps)
        XCTAssertEqual(settings.frequency, .everyThirdOpen)
        XCTAssertTrue(settings.remindInWatchedApps)
        XCTAssertEqual(settings.remindAfterMinutes, 15)
        XCTAssertEqual(settings.watchedSummary, "Instagram, TikTok")
        XCTAssertFalse(settings.pauseDuringQuietHours)
        XCTAssertEqual(settings.quietHoursDescription, "From 10 PM to 7 AM.")
    }

    func testRoundTripAndForwardCompatibility() throws {
        let suite = "waih.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.load(), WAIHSettings())

        var settings = WAIHSettings()
        settings.frequency = .afterThirtyMinutesAway
        settings.remindAfterMinutes = 25
        settings.customApps = [try XCTUnwrap(WatchedApp.custom(name: "My Feed!", urlScheme: "myfeed://"))]
        settings.watchedAppIDs.append("custom-my-feed")
        store.save(settings)
        XCTAssertEqual(store.load(), settings)

        // A blob from a build that knew fewer fields, with an out-of-range value.
        defaults.set(Data(#"{"frequency":"everyOpen","remindAfterMinutes":500}"#.utf8), forKey: "waih.settings.v1")
        let loaded = store.load()
        XCTAssertEqual(loaded.frequency, .everyOpen)
        XCTAssertEqual(loaded.remindAfterMinutes, 60)
        XCTAssertEqual(loaded.watchedAppIDs, ["instagram", "tiktok"])

        defaults.set(Data("not json".utf8), forKey: "waih.settings.v1")
        XCTAssertEqual(store.load(), WAIHSettings())
    }

    func testWatchedSummary() {
        var settings = WAIHSettings()
        settings.watchedAppIDs = []
        XCTAssertEqual(settings.watchedSummary, "None")
        settings.watchedAppIDs = ["youtube", "instagram", "tiktok", "reddit"]
        XCTAssertEqual(settings.watchedSummary, "Instagram, TikTok + 2")
    }

    func testCustomAppAndLaunchURL() {
        XCTAssertEqual(WatchedApp.custom(name: " My Feed! ", urlScheme: " myfeed:// ")?.id, "custom-my-feed")
        XCTAssertEqual(WatchedApp.custom(name: "My Feed", urlScheme: "myfeed://")?.launchURL?.absoluteString, "myfeed://")
        XCTAssertNil(WatchedApp.custom(name: "  ", urlScheme: "x"))
        XCTAssertNil(WatchedApp.custom(name: "Feed", urlScheme: "")?.launchURL)
        XCTAssertEqual(Set(AppCatalog.builtIn.map(\.id)).count, AppCatalog.builtIn.count)
        XCTAssertTrue(AppCatalog.builtIn.allSatisfy { $0.launchURL != nil })
    }

    func testQuietHourWindows() {
        var settings = WAIHSettings()
        XCTAssertFalse(settings.isQuiet(at: date(3, 23), calendar: testCalendar), "off until the user turns it on")
        settings.pauseDuringQuietHours = true
        XCTAssertTrue(settings.isQuiet(at: date(3, 22), calendar: testCalendar))
        XCTAssertTrue(settings.isQuiet(at: date(3, 2), calendar: testCalendar))
        XCTAssertFalse(settings.isQuiet(at: date(3, 7), calendar: testCalendar))
        XCTAssertFalse(settings.isQuiet(at: date(3, 21, 59), calendar: testCalendar))
        settings.quietStartHour = 13
        settings.quietEndHour = 15
        XCTAssertTrue(settings.isQuiet(at: date(3, 14), calendar: testCalendar))
        XCTAssertFalse(settings.isQuiet(at: date(3, 15), calendar: testCalendar))
    }

    func testFormatting() {
        XCTAssertEqual(Format.duration(161 * 60), "2h 41m")
        XCTAssertEqual(Format.duration(41 * 60), "41m")
        XCTAssertEqual(Format.duration(0), "0m")
        XCTAssertEqual(Format.duration(120 * 60), "2h")
        XCTAssertEqual(Format.duration(17 * 3600 + 20 * 60, compact: true), "17h")
        XCTAssertEqual(Format.duration(9 * 3600 + 20 * 60, compact: true), "9h 20m")
        XCTAssertEqual(Format.hour(0), "12 AM")
        XCTAssertEqual(Format.hour(12), "12 PM")
        XCTAssertEqual(Format.dayHeader(date(3), calendar: testCalendar), "Mon, Nov 3")
        XCTAssertEqual(Format.time(date(3, 21, 12), calendar: testCalendar), "9:12 PM")
        XCTAssertEqual(Format.signedPercent(-8), "−8%")
        XCTAssertEqual(Format.signedPercent(8), "+8%")
        XCTAssertEqual(Format.trend(-8), "Down 8%")
        XCTAssertEqual(Format.trend(8), "Up 8%")
        XCTAssertEqual(Format.trend(0), "No Change")
    }

    @MainActor
    func testDemoDataReproducesPrototypeToday() throws {
        let store = try PickupStore(inMemory: true)
        let now = date(6, 21, 12) // Thursday evening
        DemoData.seed(store, now: now, calendar: testCalendar)
        let today = testCalendar.dateInterval(of: .day, for: now)!
        let summary = Stats.day(records: store.records(in: today), on: now, now: now, calendar: testCalendar)
        XCTAssertEqual(summary.pickups, 37)
        XCTAssertEqual(summary.mindless, 14)
        XCTAssertEqual(summary.intentionalPercent, 62)
        XCTAssertEqual(Format.duration(summary.screenTime), "2h 41m")
        XCTAssertEqual(summary.topReasons.map(\.count), [12, 9, 7])
        XCTAssertEqual(Stats.lastCheckIn(store.lastCheckIn()?.record)?.label, "Messages")
        XCTAssertTrue(store.records(in: today).allSatisfy { $0.openedAt <= now })

        let week = testCalendar.dateInterval(of: .weekOfYear, for: now)!
        let previous = DateInterval(start: testCalendar.date(byAdding: .day, value: -7, to: week.start)!, end: week.start)
        let weekly = Stats.week(records: store.records(in: week), previous: store.records(in: previous),
                                now: now, calendar: testCalendar)
        XCTAssertEqual(weekly.changePercent, -8)
        XCTAssertEqual(weekly.days.map(\.count), [30, 26, 33, 37, 0, 0, 0])
    }
}

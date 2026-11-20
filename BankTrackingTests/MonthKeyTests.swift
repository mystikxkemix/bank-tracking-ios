import XCTest
@testable import BankTracking

final class MonthKeyTests: XCTestCase {
    func testParsesAndFormatsApiKeys() {
        XCTAssertEqual(MonthKey("2026-03")?.key, "2026-03")
        XCTAssertNil(MonthKey("2026-13"))
        XCTAssertNil(MonthKey("2026"))
        XCTAssertNil(MonthKey("abcd-ef"))
    }

    func testAddingCrossesYears() {
        let january: MonthKey = MonthKey(year: 2026, month: 1)
        XCTAssertEqual(january.adding(-1), MonthKey(year: 2025, month: 12))
        XCTAssertEqual(january.adding(11), MonthKey(year: 2026, month: 12))
        XCTAssertEqual(january.adding(12), MonthKey(year: 2027, month: 1))
        XCTAssertEqual(january.adding(-13), MonthKey(year: 2024, month: 12))
    }

    func testOrdering() {
        XCTAssertLessThan(MonthKey(year: 2025, month: 12), MonthKey(year: 2026, month: 1))
    }

    func testFrenchTitles() {
        XCTAssertEqual(MonthKey(year: 2026, month: 8).title, "Août 2026")
        XCTAssertEqual(MonthKey(year: 2026, month: 11).shortTitle, "nov. 26")
    }

    func testDayFormat() {
        XCTAssertEqual(DayFormat.long("2026-11-02"), "Lundi 2 novembre")
        XCTAssertEqual(DayFormat.medium("2026-11-02"), "2 nov. 2026")
        XCTAssertEqual(DayFormat.long("bad"), "bad")
    }

    func testCurrentMonthUsesCalendar() {
        var calendar: Calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date: Date = Date(timeIntervalSince1970: 1_795_000_000) // 2026-11-18
        XCTAssertEqual(MonthKey.current(calendar: calendar, now: date).key, "2026-11")
    }
}

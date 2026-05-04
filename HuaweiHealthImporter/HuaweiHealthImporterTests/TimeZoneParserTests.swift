import XCTest
@testable import HuaweiHealthImporter

final class TimeZoneParserTests: XCTestCase {

    func testPositiveOffset() {
        let tz = TimeZoneParser.parseOffset("+0200")
        XCTAssertEqual(tz.secondsFromGMT(), 2 * 3600)
    }

    func testNegativeOffset() {
        let tz = TimeZoneParser.parseOffset("-0530")
        XCTAssertEqual(tz.secondsFromGMT(), -(5 * 3600 + 30 * 60))
    }

    func testZeroOffset() {
        let tz = TimeZoneParser.parseOffset("+0000")
        XCTAssertEqual(tz.secondsFromGMT(), 0)
    }

    func testNilReturnsCurrentTimeZone() {
        let tz = TimeZoneParser.parseOffset(nil)
        XCTAssertEqual(tz.identifier, TimeZone.current.identifier)
    }

    func testInvalidStringReturnsCurrentTimeZone() {
        let tz = TimeZoneParser.parseOffset("UTC")
        XCTAssertEqual(tz.identifier, TimeZone.current.identifier)
    }

    func testDateFromUnixMs() {
        // 1602675000000 ms = 2020-10-14 14:50:00 UTC
        let date = TimeZoneParser.date(fromUnixMs: 1_602_675_000_000)
        XCTAssertEqual(date.timeIntervalSince1970, 1_602_675_000.0, accuracy: 0.001)
    }

    func testColonSeparatedOffset() {
        let tz = TimeZoneParser.parseOffset("+02:00")
        XCTAssertEqual(tz.secondsFromGMT(), 2 * 3600)
    }
}

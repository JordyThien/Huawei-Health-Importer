import XCTest
@testable import HuaweiHealthImporter

/// Verifies that all pinned fixture files parse cleanly.
final class FixturesTests: XCTestCase {

    func testHeartRateFixtureDecodesSuccessfully() throws {
        let url = try fixtureURL(named: "heartrate_sample")
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.samplePoints.first?.key, "DATA_POINT_DYNAMIC_HEARTRATE")
    }

    func testWeightFixtureDecodesSuccessfully() throws {
        let url = try fixtureURL(named: "weight_sample")
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.samplePoints.first?.key, "WEIGHT_BODYFAT_BROAD")
    }

    func testSleepFixtureDecodesSuccessfully() throws {
        let url = try fixtureURL(named: "sleep_sample")
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.samplePoints.first?.key, "PROFESSIONAL_SLEEP_SHALLOW")
    }

    func testSportFixtureDecodesSuccessfully() throws {
        let url = try fixtureURL(named: "sport_per_minute_sample")
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiSportRecord].self, from: data)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.sportDataUserData.first?.sportBasicInfos.first?.steps, 14)
    }

    // MARK: - Helpers

    private func fixtureURL(named name: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"),
                             "Missing fixture: \(name).json")
    }
}

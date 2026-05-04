import XCTest
import HealthKit
@testable import HuaweiHealthImporter

final class SleepMapperTests: XCTestCase {

    private func loadPoint() throws -> HuaweiSamplePoint {
        let url = Bundle(for: type(of: self)).url(forResource: "sleep_sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        return try XCTUnwrap(records.first?.samplePoints.first)
    }

    func testShallowSleepMapsToCore() throws {
        let point = try loadPoint()
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.value, HKCategoryValueSleepAnalysis.asleepCore.rawValue)
    }

    func testCorrectDates() throws {
        let point = try loadPoint()
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.startDate.timeIntervalSince1970, 1_603_232_760.0, accuracy: 0.001)
        XCTAssertEqual(sample.endDate.timeIntervalSince1970, 1_603_232_820.0, accuracy: 0.001)
    }

    func testDeepSleepMapping() throws {
        let point = HuaweiSamplePoint(key: "PROFESSIONAL_SLEEP_DEEP",
                                       startTime: 1000, endTime: 2000, unit: nil, value: "")
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.value, HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
    }

    func testREMMapsCorrectly() throws {
        let point = HuaweiSamplePoint(key: "PROFESSIONAL_SLEEP_DREAM",
                                       startTime: 1000, endTime: 2000, unit: nil, value: "")
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.value, HKCategoryValueSleepAnalysis.asleepREM.rawValue)
    }

    func testWakeMapsCorrectly() throws {
        let point = HuaweiSamplePoint(key: "PROFESSIONAL_SLEEP_WAKE",
                                       startTime: 1000, endTime: 2000, unit: nil, value: "")
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.value, HKCategoryValueSleepAnalysis.awake.rawValue)
    }

    func testNoonMapsToUnspecified() throws {
        let point = HuaweiSamplePoint(key: "PROFESSIONAL_SLEEP_NOON",
                                       startTime: 1000, endTime: 2000, unit: nil, value: "")
        let sample = try XCTUnwrap(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.value, HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
    }

    func testUnknownKeyReturnsNil() {
        let point = HuaweiSamplePoint(key: "UNKNOWN_KEY",
                                       startTime: 1000, endTime: 2000, unit: nil, value: "")
        XCTAssertNil(SleepMapper.sample(from: point, recordId: nil, deviceCode: nil))
    }
}

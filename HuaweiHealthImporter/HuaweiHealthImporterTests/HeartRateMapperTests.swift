import XCTest
import HealthKit
@testable import HuaweiHealthImporter

final class HeartRateMapperTests: XCTestCase {

    private func loadFixture() throws -> HuaweiSamplePoint {
        let url = Bundle(for: type(of: self)).url(forResource: "heartrate_sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        return try XCTUnwrap(records.first?.samplePoints.first)
    }

    func testMapsCorrectBPM() throws {
        let point = try loadFixture()
        let sample = try XCTUnwrap(HeartRateMapper.sample(from: point, recordId: "test-id", deviceCode: 12345))
        let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        XCTAssertEqual(bpm, 82.0, accuracy: 0.001)
    }

    func testMapsCorrectDates() throws {
        let point = try loadFixture()
        let sample = try XCTUnwrap(HeartRateMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.startDate.timeIntervalSince1970, 1_602_675_000.0, accuracy: 0.001)
        XCTAssertEqual(sample.endDate.timeIntervalSince1970, 1_602_675_060.0, accuracy: 0.001)
    }

    func testRecordIdStoredInMetadata() throws {
        let point = try loadFixture()
        let sample = try XCTUnwrap(HeartRateMapper.sample(from: point, recordId: "test-uuid", deviceCode: nil))
        let uuid = sample.metadata?[HKMetadataKeyExternalUUID] as? String
        XCTAssertEqual(uuid, "test-uuid")
    }

    func testNilForInvalidValue() {
        let point = HuaweiSamplePoint(key: "DATA_POINT_DYNAMIC_HEARTRATE",
                                      startTime: 1000, endTime: 2000,
                                      unit: "0", value: "not-a-number")
        XCTAssertNil(HeartRateMapper.sample(from: point, recordId: nil, deviceCode: nil))
    }

    func testNilForOutOfRangeValue() {
        let point = HuaweiSamplePoint(key: "DATA_POINT_DYNAMIC_HEARTRATE",
                                      startTime: 1000, endTime: 2000,
                                      unit: "0", value: "999.0")
        XCTAssertNil(HeartRateMapper.sample(from: point, recordId: nil, deviceCode: nil))
    }
}

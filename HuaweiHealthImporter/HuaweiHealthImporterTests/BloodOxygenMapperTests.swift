import XCTest
import HealthKit
@testable import HuaweiHealthImporter

final class BloodOxygenMapperTests: XCTestCase {

    func testEmbeddedJSONValue() {
        // Real Huawei format: embedded JSON {"avgSaturation":98.0}
        let point = HuaweiSamplePoint(
            key: "BLOOD_OXYGEN_SATURATION",
            startTime: 1_602_708_300_000,
            endTime: 1_602_708_360_000,
            unit: "0",
            value: "{\"avgSaturation\":98.0}"
        )
        let sample = BloodOxygenMapper.sample(from: point, recordId: "test-id", deviceCode: nil)
        XCTAssertNotNil(sample)
        // HK expects fraction: 98% → 0.98
        let fraction = sample!.quantity.doubleValue(for: .percent())
        XCTAssertEqual(fraction, 0.98, accuracy: 0.0001)
    }

    func testPlainNumericValue() {
        // Fallback: plain "98.0"
        let point = HuaweiSamplePoint(
            key: "BLOOD_OXYGEN_SATURATION",
            startTime: 1000, endTime: 2000, unit: "0", value: "98.0"
        )
        let sample = BloodOxygenMapper.sample(from: point, recordId: nil, deviceCode: nil)
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample!.quantity.doubleValue(for: .percent()), 0.98, accuracy: 0.0001)
    }

    func testAlreadyFractionValue() {
        // If value is already in fraction form (e.g. 0.98)
        let point = HuaweiSamplePoint(
            key: "BLOOD_OXYGEN_SATURATION",
            startTime: 1000, endTime: 2000, unit: "0", value: "0.98"
        )
        let sample = BloodOxygenMapper.sample(from: point, recordId: nil, deviceCode: nil)
        XCTAssertNotNil(sample)
        XCTAssertEqual(sample!.quantity.doubleValue(for: .percent()), 0.98, accuracy: 0.0001)
    }

    func testNilForEmptyValue() {
        let point = HuaweiSamplePoint(
            key: "BLOOD_OXYGEN_SATURATION",
            startTime: 1000, endTime: 2000, unit: "0", value: ""
        )
        XCTAssertNil(BloodOxygenMapper.sample(from: point, recordId: nil, deviceCode: nil))
    }

    func testCorrectDates() throws {
        let point = HuaweiSamplePoint(
            key: "BLOOD_OXYGEN_SATURATION",
            startTime: 1_602_708_300_000,
            endTime: 1_602_708_360_000,
            unit: "0", value: "{\"avgSaturation\":98.0}"
        )
        let sample = try XCTUnwrap(BloodOxygenMapper.sample(from: point, recordId: nil, deviceCode: nil))
        XCTAssertEqual(sample.startDate.timeIntervalSince1970, 1_602_708_300.0, accuracy: 0.001)
        XCTAssertEqual(sample.endDate.timeIntervalSince1970, 1_602_708_360.0, accuracy: 0.001)
    }
}

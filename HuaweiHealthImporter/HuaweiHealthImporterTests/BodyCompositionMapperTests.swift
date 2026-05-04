import XCTest
import HealthKit
@testable import HuaweiHealthImporter

final class BodyCompositionMapperTests: XCTestCase {

    private func loadPoint() throws -> HuaweiSamplePoint {
        let url = Bundle(for: type(of: self)).url(forResource: "weight_sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
        return try XCTUnwrap(records.first?.samplePoints.first)
    }

    func testProducesCorrectNumberOfSamples() throws {
        let point = try loadPoint()
        let samples = BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil)
        // bodyMass, bodyFatPercentage, bmi, leanBodyMass, height = 5
        XCTAssertEqual(samples.count, 5)
    }

    func testBodyMassIsCorrect() throws {
        let point = try loadPoint()
        let samples = BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil)
        let massSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.bodyMass.rawValue
        }))
        let kg = massSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        XCTAssertEqual(kg, 70.0, accuracy: 0.01)
    }

    func testBodyFatPercentageIsCorrect() throws {
        let point = try loadPoint()
        let samples = BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil)
        let bfSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.bodyFatPercentage.rawValue
        }))
        // 15.0% → fraction 0.15
        let fraction = bfSample.quantity.doubleValue(for: .percent())
        XCTAssertEqual(fraction, 0.15, accuracy: 0.0001)
    }

    func testHeightInCentimetres() throws {
        let point = try loadPoint()
        let samples = BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil)
        let htSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.height.rawValue
        }))
        let cm = htSample.quantity.doubleValue(for: .meterUnit(with: .centi))
        XCTAssertEqual(cm, 180.0, accuracy: 0.01)
    }

    func testLeanBodyMassDerived() throws {
        let point = try loadPoint()
        let samples = BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil)
        let lbmSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.leanBodyMass.rawValue
        }))
        // 70.0 * (1 - 0.15) = 59.5
        let kg = lbmSample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        XCTAssertEqual(kg, 70.0 * (1.0 - 0.15), accuracy: 0.01)
    }

    func testEmptyValueReturnsNoSamples() {
        let point = HuaweiSamplePoint(key: "WEIGHT_BODYFAT_BROAD",
                                      startTime: 1000, endTime: 2000,
                                      unit: "0", value: "")
        XCTAssertTrue(BodyCompositionMapper.samples(from: point, recordId: nil, deviceCode: nil).isEmpty)
    }
}

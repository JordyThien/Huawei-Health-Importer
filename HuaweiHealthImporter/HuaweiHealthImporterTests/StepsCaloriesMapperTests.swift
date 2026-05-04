import XCTest
import HealthKit
@testable import HuaweiHealthImporter

final class StepsCaloriesMapperTests: XCTestCase {

    private func makeEntry(steps: Int = 14, distance: Int = 9, calorie: Int = 269) -> HuaweiSportEntry {
        let info = HuaweiSportBasicInfo(steps: steps, distance: distance, calorie: calorie,
                                         altitude: 0, floor: 0, duration: 1, count: 0)
        return HuaweiSportEntry(startTime: 1_554_497_100_000, endTime: 1_554_497_160_000,
                                 timeZone: "+0200", deviceCode: 182629895,
                                 sportType: 5, sportBasicInfos: [info])
    }

    override func setUp() {
        super.setUp()
        StepsCaloriesMapper.calorieDivisor = 10.0
    }

    func testProducesThreeSamples() {
        let samples = StepsCaloriesMapper.samples(from: makeEntry())
        XCTAssertEqual(samples.count, 3)
    }

    func testStepCountCorrect() throws {
        let samples = StepsCaloriesMapper.samples(from: makeEntry())
        let stepSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue
        }))
        XCTAssertEqual(stepSample.quantity.doubleValue(for: .count()), 14.0, accuracy: 0.001)
    }

    func testDistanceCorrect() throws {
        let samples = StepsCaloriesMapper.samples(from: makeEntry())
        let distSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue
        }))
        XCTAssertEqual(distSample.quantity.doubleValue(for: .meter()), 9.0, accuracy: 0.001)
    }

    func testCalorieWithDefaultDivisor() throws {
        let samples = StepsCaloriesMapper.samples(from: makeEntry(calorie: 269))
        let calSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue
        }))
        XCTAssertEqual(calSample.quantity.doubleValue(for: .kilocalorie()), 26.9, accuracy: 0.001)
    }

    func testCalorieWithCustomDivisor() throws {
        StepsCaloriesMapper.calorieDivisor = 1.0
        let samples = StepsCaloriesMapper.samples(from: makeEntry(calorie: 269))
        let calSample = try XCTUnwrap(samples.first(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.activeEnergyBurned.rawValue
        }))
        XCTAssertEqual(calSample.quantity.doubleValue(for: .kilocalorie()), 269.0, accuracy: 0.001)
    }

    func testZeroStepsProducesOnlyDistanceAndCalorie() {
        let samples = StepsCaloriesMapper.samples(from: makeEntry(steps: 0))
        XCTAssertFalse(samples.contains(where: {
            $0.sampleType.identifier == HKQuantityTypeIdentifier.stepCount.rawValue
        }))
    }

    func testLoadFromFixture() throws {
        let url = Bundle(for: type(of: self)).url(forResource: "sport_per_minute_sample", withExtension: "json")!
        let data = try Data(contentsOf: url)
        let sportRecords = try JSONDecoder().decode([HuaweiSportRecord].self, from: data)
        let entry = try XCTUnwrap(sportRecords.first?.sportDataUserData.first)
        let samples = StepsCaloriesMapper.samples(from: entry)
        XCTAssertEqual(samples.count, 3)
    }
}

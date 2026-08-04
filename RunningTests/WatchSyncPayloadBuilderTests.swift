import XCTest
@testable import Running

final class WatchSyncPayloadBuilderTests: XCTestCase {
    func testMakeContextIncludesPlansLanguageVibrationAndVolume() throws {
        let plan = SavedPlan(
            name: "Test Plan",
            trainingType: .paceRun,
            configData: Data([0x01, 0x02, 0x03])
        )
        let settings = UserSettings(
            userId: "user-1",
            language: "zh-Hans",
            soundConfig: SoundConfig(volume: 0.42, vibrationEnabled: false),
            countdownSeconds: 5,
            autoConnectBluetooth: true,
            speedUnit: 1
        )

        let context = WatchSyncPayloadBuilder.makeContext(plans: [plan], settings: settings)

        XCTAssertEqual(context["language"] as? String, "zh-Hans")
        XCTAssertEqual(context["vibrationEnabled"] as? Bool, false)
        let volume = try XCTUnwrap(context["soundVolume"] as? Float)
        XCTAssertEqual(volume, 0.42, accuracy: 0.0001)

        let plansData = try XCTUnwrap(context["plans"] as? Data)
        let decodedPlans = try JSONDecoder().decode([SavedPlan].self, from: plansData)
        XCTAssertEqual(decodedPlans.count, 1)
        XCTAssertEqual(decodedPlans.first?.name, "Test Plan")
    }
}

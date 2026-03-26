import XCTest
@testable import Running

final class AppRuntimeConfigurationTests: XCTestCase {
    func testDisablesAudioWhenUITestAudioFlagIsPresent() {
        XCTAssertTrue(AppRuntimeConfiguration.shouldDisableAudio(arguments: ["-ui_testing_disable_sound"]))
    }

    func testDoesNotDisableAudioWithoutExplicitFlag() {
        XCTAssertFalse(AppRuntimeConfiguration.shouldDisableAudio(arguments: []))
        XCTAssertFalse(AppRuntimeConfiguration.shouldDisableAudio(arguments: ["-ui_testing_reset"]))
    }
}

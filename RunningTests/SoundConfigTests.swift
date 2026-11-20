import XCTest
@testable import Running

final class SoundConfigTests: XCTestCase {
    func testSoundTypeIncludesProfessionalStandardWhistleOption() {
        XCTAssertTrue(SoundType.allCases.contains(.whistleStandard))
        XCTAssertEqual(SoundType.whistleStandard.displayNameKey, "sound_whistle_standard")
    }

    func testSoundTypeIncludesCrispShortWhistleOption() {
        XCTAssertTrue(SoundType.allCases.contains(.whistleQixinlu))
        XCTAssertEqual(SoundType.whistleQixinlu.displayNameKey, "sound_whistle_crisp_short")
    }

    func testDefaultSoundConfigValues() {
        let config = SoundConfig()
        XCTAssertEqual(config.volume, 1.0)
        XCTAssertTrue(config.vibrationEnabled)
    }
}

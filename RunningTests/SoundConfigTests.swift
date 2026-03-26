import XCTest
@testable import Running

final class SoundConfigTests: XCTestCase {
    func testSoundTypeIncludesProfessionalStandardWhistleOption() {
        XCTAssertTrue(SoundType.allCases.contains(.whistleStandard))
        XCTAssertEqual(SoundType.whistleStandard.displayNameKey, "sound_whistle_standard")
    }

    func testSoundTypeIncludesQixinluWhistleOption() {
        XCTAssertTrue(SoundType.allCases.contains(.whistleQixinlu))
        XCTAssertEqual(SoundType.whistleQixinlu.displayNameKey, "sound_whistle_qixinlu")
    }

    func testDefaultRunStartSoundUsesProfessionalWhistle() {
        XCTAssertEqual(SoundConfig().runStartSound, .whistleStandard)
    }
}

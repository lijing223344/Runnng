import XCTest
@testable import Running

final class SoundCueMigrationTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private let migrationFlagKey = "sound_cue_migration_v1"

    override func setUp() {
        super.setUp()
        clearState()
    }

    override func tearDown() {
        clearState()
        super.tearDown()
    }

    private func clearState() {
        defaults.removeObject(forKey: migrationFlagKey)
        for key in ["pace_run_training", "interval_training_single", "saved_plans"] {
            defaults.removeObject(forKey: key)
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("sound_cue_migration_v1::") {
            defaults.removeObject(forKey: key)
        }
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix("pace_run_training::") || key.hasPrefix("interval_training_single::") || key.hasPrefix("saved_plans::") {
            defaults.removeObject(forKey: key)
        }
    }

    func testLegacyUniformWhistleBecomesThreeDistinctCues() {
        var group = PaceRunGroup()
        group.startSound = .whistleShort
        group.segmentSound = .whistleShort
        group.endSound = .whistleShort
        StorageManager.shared.savePaceRunTraining(PaceRunTraining(groups: [group]))

        StorageManager.shared.migrateLegacySoundCuesIfNeeded()

        let migrated = StorageManager.shared.loadPaceRunTraining()
        XCTAssertEqual(migrated?.groups.first?.startSound, .startTriad)
        XCTAssertEqual(migrated?.groups.first?.segmentSound, .splitTick)
        XCTAssertEqual(migrated?.groups.first?.endSound, .finishArpeggio)
    }

    func testIntervalLegacyTripleBecomesGoRestFinish() {
        var group = IntervalGroup()
        group.startSound = .whistleShort
        group.restSound = .whistleShort
        group.endSound = .whistleShort
        StorageManager.shared.saveIntervalTrainingSingle(IntervalTraining(groups: [group]))

        StorageManager.shared.migrateLegacySoundCuesIfNeeded()

        let migrated = StorageManager.shared.loadIntervalTrainingSingle()
        XCTAssertEqual(migrated?.groups.first?.startSound, .startTriad)
        XCTAssertEqual(migrated?.groups.first?.restSound, .restBell)
        XCTAssertEqual(migrated?.groups.first?.endSound, .finishArpeggio)
    }

    func testCustomisedGroupIsLeftUntouched() {
        var group = PaceRunGroup()
        group.startSound = .whistleStandard
        group.segmentSound = .buzzer
        group.endSound = .whistleShort
        StorageManager.shared.savePaceRunTraining(PaceRunTraining(groups: [group]))

        StorageManager.shared.migrateLegacySoundCuesIfNeeded()

        let migrated = StorageManager.shared.loadPaceRunTraining()
        XCTAssertEqual(migrated?.groups.first?.startSound, .whistleStandard)
        XCTAssertEqual(migrated?.groups.first?.segmentSound, .buzzer)
        XCTAssertEqual(migrated?.groups.first?.endSound, .whistleShort)
    }

    func testDefaultGroupUsesDistinctCues() {
        let group = PaceRunGroup()
        XCTAssertEqual(group.startSound, .startTriad)
        XCTAssertEqual(group.segmentSound, .splitTick)
        XCTAssertEqual(group.endSound, .finishArpeggio)

        let interval = IntervalGroup()
        XCTAssertEqual(interval.startSound, .startTriad)
        XCTAssertEqual(interval.restSound, .restBell)
        XCTAssertEqual(interval.endSound, .finishArpeggio)
    }
}

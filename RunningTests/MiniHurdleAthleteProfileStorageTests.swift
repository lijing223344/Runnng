import XCTest
@testable import Running

final class MiniHurdleAthleteProfileStorageTests: XCTestCase {
    private let storage = StorageManager.shared

    override func setUp() {
        super.setUp()
        storage.resetForUITests()
    }

    override func tearDown() {
        storage.resetForUITests()
        super.tearDown()
    }

    func testMiniHurdleProfilesLoadSortedByLastUsedThenUpdated() {
        let oldDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let newestDate = Date(timeIntervalSince1970: 300)

        let first = makeProfile(
            name: "甲组",
            updatedAt: newerDate,
            lastUsedAt: oldDate
        )
        let second = makeProfile(
            name: "乙组",
            greaterTrochanterLength: 0.92,
            strategyKind: .clarkRange,
            customRatio: 2.41,
            updatedAt: oldDate,
            lastUsedAt: newestDate
        )
        let third = makeProfile(
            name: "丙组",
            updatedAt: newestDate,
            lastUsedAt: newerDate
        )

        storage.saveMiniHurdleProfiles([first, second, third])

        let loaded = storage.loadMiniHurdleProfiles()

        XCTAssertEqual(loaded.map(\.name), ["乙组", "丙组", "甲组"])
    }

    func testUpsertMiniHurdleProfileReplacesExistingRecord() throws {
        let id = UUID()
        let original = makeProfile(
            id: id,
            name: "王强",
            greaterTrochanterLength: 0.88,
            updatedAt: Date(timeIntervalSince1970: 100),
            lastUsedAt: Date(timeIntervalSince1970: 120)
        )
        let updated = makeProfile(
            id: id,
            name: "王强",
            profile: .men,
            greaterTrochanterLength: 0.94,
            measurementUnit: .meters,
            strategyKind: .clarkRange,
            customRatio: 2.48,
            updatedAt: Date(timeIntervalSince1970: 200),
            lastUsedAt: Date(timeIntervalSince1970: 220)
        )

        storage.saveMiniHurdleProfiles([original])
        storage.upsertMiniHurdleProfile(updated)

        let loaded = try XCTUnwrap(storage.loadMiniHurdleProfiles().first)
        XCTAssertEqual(storage.loadMiniHurdleProfiles().count, 1)
        XCTAssertEqual(loaded.id, id)
        XCTAssertEqual(loaded.profile, .men)
        XCTAssertEqual(loaded.greaterTrochanterLength, 0.94, accuracy: 0.0001)
        XCTAssertEqual(loaded.measurementUnit, .meters)
        XCTAssertEqual(loaded.strategyKind, .clarkRange)
        XCTAssertEqual(try XCTUnwrap(loaded.customRatio), 2.48, accuracy: 0.0001)
        XCTAssertEqual(loaded.lastUsedAt, Date(timeIntervalSince1970: 220))
    }

    func testDeletingSelectedMiniHurdleProfileClearsSelection() {
        let first = makeProfile(name: "A")
        let second = makeProfile(name: "B")

        storage.saveMiniHurdleProfiles([first, second])
        storage.saveSelectedMiniHurdleProfileID(first.id)

        storage.deleteMiniHurdleProfile(first.id)

        XCTAssertEqual(storage.loadMiniHurdleProfiles().map(\.id), [second.id])
        XCTAssertNil(storage.loadSelectedMiniHurdleProfileID())
    }

    func testMiniHurdleProfilesAreScopedBetweenLoggedInUsers() {
        storage.saveUser(User(id: "runner-a", appleId: "runner-a", nickname: "A"))
        storage.saveMiniHurdleProfiles([makeProfile(name: "A1")])
        storage.saveSelectedMiniHurdleProfileID(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))

        storage.saveUser(User(id: "runner-b", appleId: "runner-b", nickname: "B"))

        XCTAssertTrue(storage.loadMiniHurdleProfiles().isEmpty)
        XCTAssertNil(storage.loadSelectedMiniHurdleProfileID())
    }

    func testLoggedInUserDoesNotReadGuestMiniHurdleProfiles() {
        storage.loginAsGuest()
        let guestProfile = makeProfile(name: "游客")
        storage.saveMiniHurdleProfiles([guestProfile])
        storage.saveSelectedMiniHurdleProfileID(guestProfile.id)

        storage.saveUser(User(id: "runner-c", appleId: "runner-c", nickname: "C"))

        XCTAssertTrue(storage.loadMiniHurdleProfiles().isEmpty)
        XCTAssertNil(storage.loadSelectedMiniHurdleProfileID())
    }

    private func makeProfile(
        id: UUID = UUID(),
        name: String,
        profile: MiniHurdleProfile = .women,
        greaterTrochanterLength: Double = 0.86,
        measurementUnit: MiniHurdleMeasurementUnit = .centimeters,
        strategyKind: MiniHurdleStrategyKind = .mannRecommended,
        customRatio: Double? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 100),
        lastUsedAt: Date = Date(timeIntervalSince1970: 100)
    ) -> MiniHurdleAthleteProfile {
        MiniHurdleAthleteProfile(
            id: id,
            name: name,
            profile: profile,
            greaterTrochanterLength: greaterTrochanterLength,
            measurementUnit: measurementUnit,
            strategyKind: strategyKind,
            customRatio: customRatio,
            updatedAt: updatedAt,
            lastUsedAt: lastUsedAt
        )
    }
}

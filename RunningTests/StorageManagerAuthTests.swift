import XCTest
@testable import Running

final class StorageManagerAuthTests: XCTestCase {
    private let storage = StorageManager.shared
    private let defaults = UserDefaults.standard

    override func setUp() {
        super.setUp()
        storage.resetForUITests()
    }

    override func tearDown() {
        storage.resetForUITests()
        super.tearDown()
    }

    func testLoadUserAppliesPersistedGuestFlagsWithoutSavedUser() {
        storage.logout()
        defaults.removeObject(forKey: "user")
        defaults.set(true, forKey: "is_guest")
        defaults.set(false, forKey: "is_logged_in")

        storage.loadUser()

        XCTAssertFalse(storage.isLoggedIn)
        XCTAssertTrue(storage.isGuest)
    }

    func testLoginAsGuestClearsCurrentUser() {
        storage.saveUser(User(id: "apple-user-1", appleId: "apple-user-1", nickname: "A"))

        storage.loginAsGuest()

        XCTAssertNil(storage.currentUser)
        XCTAssertFalse(storage.isLoggedIn)
        XCTAssertTrue(storage.isGuest)
    }

    func testSettingsAreIsolatedBetweenLoggedInUsers() {
        storage.saveUser(User(id: "apple-user-a", appleId: "apple-user-a", nickname: "A"))
        var settingsForA = storage.loadSettings()
        settingsForA.language = "en"
        storage.saveSettings(settingsForA)

        storage.saveUser(User(id: "apple-user-b", appleId: "apple-user-b", nickname: "B"))
        let settingsForB = storage.loadSettings()

        XCTAssertEqual(settingsForB.language, "system")
    }

    func testLoggedInUserDoesNotReadGuestSettingsBucket() {
        storage.loginAsGuest()
        var guestSettings = storage.loadSettings()
        guestSettings.language = "en"
        storage.saveSettings(guestSettings)

        storage.saveUser(User(id: "apple-user-c", appleId: "apple-user-c", nickname: "C"))
        let userSettings = storage.loadSettings()

        XCTAssertEqual(userSettings.language, "system")
    }

    func testDeleteCurrentAccountClearsScopedDataAndAuthState() {
        let userId = "apple-user-delete"
        storage.saveUser(User(id: userId, appleId: userId, nickname: "D"))

        var settings = storage.loadSettings()
        settings.language = "en"
        storage.saveSettings(settings)

        let scopedSettingsKey = "user_settings::\(userId)"
        XCTAssertNotNil(defaults.data(forKey: scopedSettingsKey))

        storage.deleteCurrentAccount()

        XCTAssertNil(storage.currentUser)
        XCTAssertFalse(storage.isLoggedIn)
        XCTAssertFalse(storage.isGuest)
        XCTAssertNil(defaults.data(forKey: scopedSettingsKey))
        XCTAssertFalse(defaults.bool(forKey: "is_logged_in"))
    }
}

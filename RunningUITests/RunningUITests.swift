import XCTest

final class RunningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += ["-ui_testing_reset", "-ui_testing_disable_sound", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-app_language", "en"]
        app.launch()
        return app
    }

    @discardableResult
    private func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.1,
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return condition()
    }

    private func openPaceTrainingPlans(_ app: XCUIApplication) {
        let manage = app.buttons["pace_manage_button"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()
        XCTAssertTrue(app.buttons["pace_add_plan_toolbar_button"].waitForExistence(timeout: 3))
    }

    private func addDefaultPaceGroup(_ app: XCUIApplication) {
        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
    }

    private func openIntervalTrainingPlans(_ app: XCUIApplication) {
        let manage = app.buttons["interval_manage_button"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()
        XCTAssertTrue(app.buttons["interval_add_plan_toolbar_button"].waitForExistence(timeout: 3))
    }

    private func addDefaultIntervalGroup(_ app: XCUIApplication) {
        let addPlan = app.buttons["interval_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
    }

    private func stopActiveTraining(_ app: XCUIApplication) {
        let stop = app.buttons["Stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.tap()

        let confirm = app.alerts.buttons["Confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
    }

    private func openSettingsTab(_ app: XCUIApplication) {
        let settingsTab = app.buttons["home_tab_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        XCTAssertTrue(
            app.buttons["settings_login_button"].waitForExistence(timeout: 3)
            || app.buttons["settings_logout_button"].waitForExistence(timeout: 3)
        )
    }

    func test400ModelGeneratesPaceDraftPlan() throws {
        let app = launchApp()

        let modelEntry = app.buttons["model_400_open_button"]
        XCTAssertTrue(modelEntry.waitForExistence(timeout: 5))
        modelEntry.tap()

        let targetTimeTrigger = app.buttons["model_400_target_time_field"]
        XCTAssertTrue(targetTimeTrigger.waitForExistence(timeout: 3))
        targetTimeTrigger.tap()

        let floatingInputField = app.textFields["floating_input_textfield"]
        XCTAssertTrue(floatingInputField.waitForExistence(timeout: 3))
        floatingInputField.tap()
        floatingInputField.typeText("57")

        let floatingInputConfirm = app.buttons["floating_input_confirm"]
        XCTAssertTrue(floatingInputConfirm.waitForExistence(timeout: 3))
        floatingInputConfirm.tap()

        let generateButton = app.buttons["model_400_generate_button"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3))
        generateButton.tap()

        let startButton = app.buttons["pace_start_training_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })
    }

    func test400ModelTargetFieldReplacesDefaultValue() throws {
        let app = launchApp()

        let modelEntry = app.buttons["model_400_open_button"]
        XCTAssertTrue(modelEntry.waitForExistence(timeout: 5))
        modelEntry.tap()

        let targetTimeTrigger = app.buttons["model_400_target_time_field"]
        XCTAssertTrue(targetTimeTrigger.waitForExistence(timeout: 3))
        targetTimeTrigger.tap()

        let floatingInputField = app.textFields["floating_input_textfield"]
        XCTAssertTrue(floatingInputField.waitForExistence(timeout: 3))
        floatingInputField.tap()
        floatingInputField.typeText("50")

        let floatingInputConfirm = app.buttons["floating_input_confirm"]
        XCTAssertTrue(floatingInputConfirm.waitForExistence(timeout: 3))
        floatingInputConfirm.tap()

        let generateButton = app.buttons["model_400_generate_button"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3))
        generateButton.tap()

        let generatedTitle = app.staticTexts["Women 400m 50.00 - 50m"]
        XCTAssertTrue(generatedTitle.waitForExistence(timeout: 5))
    }

    func testPaceCardTapDoesNotTriggerDuplicate() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        addDefaultPaceGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })

        let groupName = app.staticTexts["New Group"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 3))
        groupName.tap()

        XCTAssertEqual(duplicateButtons.count, 1)
    }

    func testPaceDeleteGroupDoesNotAutoSelectRemaining() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        addDefaultPaceGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })
        let duplicate = app.buttons["Duplicate group"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 3))
        duplicate.tap()
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 2 })

        var deselectButtons = app.buttons.matching(identifier: "Deselect group")
        XCTAssertTrue(waitUntil(timeout: 3) { deselectButtons.count == 2 })
        while deselectButtons.count > 0 {
            deselectButtons.firstMatch.tap()
            deselectButtons = app.buttons.matching(identifier: "Deselect group")
        }

        let startButton = app.buttons["pace_start_training_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        XCTAssertFalse(startButton.isEnabled)

        let groupName = app.staticTexts["New Group"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 3))
        groupName.swipeLeft()

        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()

        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })
        XCTAssertFalse(startButton.isEnabled)
    }

    func testIntervalCardTapDoesNotTriggerDuplicate() throws {
        let app = launchApp()
        openIntervalTrainingPlans(app)
        addDefaultIntervalGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })

        let groupName = app.staticTexts["New Group"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 3))
        groupName.tap()

        XCTAssertEqual(duplicateButtons.count, 1)
    }

    func testIntervalDeleteGroupDoesNotAutoSelectRemaining() throws {
        let app = launchApp()
        openIntervalTrainingPlans(app)
        addDefaultIntervalGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })
        let duplicate = app.buttons["Duplicate group"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 3))
        duplicate.tap()
        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 2 })

        var deselectButtons = app.buttons.matching(identifier: "Deselect group")
        XCTAssertTrue(waitUntil(timeout: 3) { deselectButtons.count == 2 })
        while deselectButtons.count > 0 {
            deselectButtons.firstMatch.tap()
            deselectButtons = app.buttons.matching(identifier: "Deselect group")
        }

        let startButton = app.buttons["interval_start_training_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        XCTAssertFalse(startButton.isEnabled)

        let groupName = app.staticTexts["New Group"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 3))
        groupName.swipeLeft()

        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 2))
        delete.tap()

        XCTAssertTrue(waitUntil(timeout: 3) { duplicateButtons.count == 1 })
        XCTAssertFalse(startButton.isEnabled)
    }

    func testPaceAddPlanDoesNotClearExistingGroups() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        addDefaultPaceGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) {
            duplicateButtons.count == 1
        })

        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(waitUntil(timeout: 3) {
            duplicateButtons.count == 2
        })
    }

    func testIntervalAddPlanDoesNotClearExistingGroups() throws {
        let app = launchApp()
        openIntervalTrainingPlans(app)
        addDefaultIntervalGroup(app)

        let duplicateButtons = app.buttons.matching(identifier: "Duplicate group")
        XCTAssertTrue(waitUntil(timeout: 3) {
            duplicateButtons.count == 1
        })

        let addPlan = app.buttons["interval_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(waitUntil(timeout: 3) {
            duplicateButtons.count == 2
        })
    }

    func testPaceHistoryEditCreatesNewPlanCopy() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        addDefaultPaceGroup(app)

        let startButton = app.buttons["pace_start_training_button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()
        stopActiveTraining(app)

        let historyTab = app.segmentedControls.buttons["History"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 3))
        historyTab.tap()

        let historyTitles = app.staticTexts.matching(identifier: "New Group")
        XCTAssertTrue(waitUntil(timeout: 3) { historyTitles.count == 1 })
        historyTitles.firstMatch.swipeLeft()

        let edit = app.buttons["pace_history_edit_button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()

        let createTab = app.segmentedControls.buttons["Create"]
        XCTAssertTrue(createTab.waitForExistence(timeout: 3))

        XCTAssertTrue(startButton.waitForExistence(timeout: 3))
        startButton.tap()
        stopActiveTraining(app)

        XCTAssertTrue(historyTab.waitForExistence(timeout: 3))
        historyTab.tap()
        XCTAssertTrue(waitUntil(timeout: 3) { historyTitles.count == 2 })
    }

    func testSettingsShowsLoginActionWhenLoggedOut() throws {
        let app = launchApp()
        openSettingsTab(app)

        XCTAssertTrue(app.buttons["settings_login_button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["settings_logout_button"].exists)
    }

    func testGuestLoginAndLogoutRoundTrip() throws {
        let app = launchApp()
        openSettingsTab(app)

        let loginButton = app.buttons["settings_login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        loginButton.tap()

        let guestButton = app.buttons["login_guest_button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 3))
        guestButton.tap()

        let logoutButton = app.buttons["settings_logout_button"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 3))
        logoutButton.tap()

        XCTAssertTrue(app.buttons["settings_login_button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["settings_logout_button"].exists)
    }

    func testGuestModeStillShowsAppleLoginEntry() throws {
        let app = launchApp()
        openSettingsTab(app)

        let loginButton = app.buttons["settings_login_button"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 3))
        loginButton.tap()

        let guestButton = app.buttons["login_guest_button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 3))
        guestButton.tap()

        XCTAssertTrue(app.buttons["settings_login_button"].waitForExistence(timeout: 3))
    }
}

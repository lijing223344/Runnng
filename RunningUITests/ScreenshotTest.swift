import XCTest

final class ScreenshotTest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning { app.terminate() }
        app.launchArguments += ["-ui_testing_reset", "-ui_testing_disable_sound", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-app_language", "zh-Hans"]
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    private var devicePrefix: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    private func save(_ screen: XCUIScreen, name: String) {
        // Attachment is the authoritative copy on every platform; the file
        // copy stays a best-effort convenience for simulator runs.
        let screenshot = screen.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(devicePrefix)_\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)

        let data = screenshot.pngRepresentation
        let url = URL(fileURLWithPath: "/Users/lgh/Documents/Running/output/\(devicePrefix)_\(name).png")
        try? data.write(to: url)
    }

    private func ensureHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    func testScreenshotAllPages() throws {
        let app = launchApp()
        sleep(2)

        // 1. Home
        save(XCUIScreen.main, name: "01_home")

        // 2. Pace Run Setup with a group
        let paceBtn = app.buttons["pace_manage_button"]
        XCTAssertTrue(paceBtn.waitForExistence(timeout: 5))
        paceBtn.tap()
        sleep(1)

        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        if addPlan.waitForExistence(timeout: 3) {
            addPlan.tap()
            sleep(1)
            // Try Chinese first, then English
            let saveBtn = app.navigationBars.buttons["保存"]
            if saveBtn.waitForExistence(timeout: 2) {
                saveBtn.tap()
            } else {
                let saveBtnEn = app.navigationBars.buttons["Save"]
                if saveBtnEn.waitForExistence(timeout: 2) { saveBtnEn.tap() }
            }
            sleep(1)
        }
        save(XCUIScreen.main, name: "02_pace_setup")

        // 3. Interval Setup with a group
        // Dismiss the pace editor sheet first (if still open), then return to Home.
        if app.buttons["pace_editor_cancel_button"].waitForExistence(timeout: 1) {
            app.buttons["pace_editor_cancel_button"].tap()
            sleep(1)
        }
        if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        let intervalBtn = app.buttons["interval_manage_button"]
        if intervalBtn.waitForExistence(timeout: 3) {
            intervalBtn.tap()
            sleep(1)

            let addInterval = app.buttons["interval_add_plan_toolbar_button"]
            if addInterval.waitForExistence(timeout: 3) {
                addInterval.tap()
                sleep(1)
                let saveBtn = app.navigationBars.buttons["保存"]
                if saveBtn.waitForExistence(timeout: 2) {
                    saveBtn.tap()
                } else {
                    let saveBtnEn = app.navigationBars.buttons["Save"]
                    if saveBtnEn.waitForExistence(timeout: 2) { saveBtnEn.tap() }
                }
                sleep(1)
            }
            save(XCUIScreen.main, name: "03_interval_setup")
        }

        // 4. Back home → History tab
        if app.buttons["interval_editor_cancel_button"].waitForExistence(timeout: 1) {
            app.buttons["interval_editor_cancel_button"].tap()
            sleep(1)
        }
        if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 2) {
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
        let historyTab = app.buttons["home_tab_history"]
        XCTAssertTrue(historyTab.waitForExistence(timeout: 5))
        historyTab.tap()
        sleep(1)
        save(XCUIScreen.main, name: "04_history")

        // 5. Settings tab
        let settingsTab = app.buttons["home_tab_settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()
        sleep(1)
        save(XCUIScreen.main, name: "05_settings")

        // 6. Model400 (CTA may sit below the fold on iPad landscape)
        let trainingTab = app.buttons["home_tab_training"]
        XCTAssertTrue(trainingTab.waitForExistence(timeout: 5))
        trainingTab.tap()
        sleep(1)

        let modelEntry = app.buttons["model_400_open_button"]
        XCTAssertTrue(modelEntry.waitForExistence(timeout: 5))
        modelEntry.tap()
        sleep(2)
        save(XCUIScreen.main, name: "06_model400")

        // 7. Mini Hurdle — top (athlete card now leads) and worksheet
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        let hurdleEntry = app.buttons["mini_hurdle_open_button"]
        XCTAssertTrue(hurdleEntry.waitForExistence(timeout: 5))
        hurdleEntry.tap()
        sleep(2)
        save(XCUIScreen.main, name: "07_mini_hurdle_top")

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        scrollView.swipeUp()
        scrollView.swipeUp()
        scrollView.swipeUp()
        sleep(1)
        save(XCUIScreen.main, name: "08_mini_hurdle_table")

        scrollView.swipeUp()
        scrollView.swipeUp()
        sleep(1)
        save(XCUIScreen.main, name: "09_mini_hurdle_progression")

        // Archive card sits between the marks table and the progression card.
        scrollView.swipeDown()
        sleep(1)
        save(XCUIScreen.main, name: "28_mini_hurdle_archive")
    }


    private func anyElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func scrollUntilHittable(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) {
        var attempts = 0
        while !element.isHittable && attempts < maxSwipes {
            app.swipeUp()
            attempts += 1
        }
    }

    // English UI pass: switch in-app language, capture the pages that carry
    // the most copy, then switch back to Chinese.
    func testScreenshotEnglishPages() throws {
        let app = launchApp()
        sleep(2)

        app.buttons["home_tab_settings"].tap()
        sleep(1)
        app.staticTexts["语言设置"].firstMatch.tap()
        sleep(2)
        save(XCUIScreen.main, name: "EN_00_language_page")
        let englishRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "英文")).firstMatch
        XCTAssertTrue(englishRow.waitForExistence(timeout: 5), "English language row not found")
        englishRow.tap()
        sleep(1)
        let done = app.buttons["language_settings_done_button"]
        if done.waitForExistence(timeout: 3) { done.tap() }
        sleep(2)

        save(XCUIScreen.main, name: "EN_01_settings")

        app.buttons["home_tab_training"].tap()
        sleep(1)
        save(XCUIScreen.main, name: "EN_02_home")
        let hurdleEntry = app.buttons["mini_hurdle_open_button"]
        if hurdleEntry.waitForExistence(timeout: 5) {
            hurdleEntry.tap()
            sleep(2)
            save(XCUIScreen.main, name: "EN_03_hurdle_top")
            app.swipeUp()
            sleep(1)
            app.swipeUp()
            sleep(1)
            save(XCUIScreen.main, name: "EN_04_hurdle_results")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        let paceBtn = app.buttons["pace_manage_button"]
        if paceBtn.waitForExistence(timeout: 3) {
            paceBtn.tap()
            sleep(1)
            save(XCUIScreen.main, name: "EN_05_pace_setup")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        let intervalBtn = app.buttons["interval_manage_button"]
        if intervalBtn.waitForExistence(timeout: 3) {
            intervalBtn.tap()
            sleep(1)
            save(XCUIScreen.main, name: "EN_06_interval_setup")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        app.buttons["home_tab_settings"].tap()
        sleep(1)
        let soundRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Sound")).firstMatch
        if soundRow.waitForExistence(timeout: 3) {
            soundRow.tap()
            sleep(2)
            save(XCUIScreen.main, name: "EN_07_sound_settings")
            app.buttons["sound_settings_done_button"].firstMatch.tap()
            sleep(1)
        }

        // History
        app.buttons["home_tab_history"].tap()
        sleep(1)
        save(XCUIScreen.main, name: "EN_08_history")

        // 400m model
        app.buttons["home_tab_training"].tap()
        sleep(1)
        let modelEntry = app.buttons["model_400_open_button"]
        if modelEntry.waitForExistence(timeout: 4) {
            modelEntry.tap()
            sleep(2)
            save(XCUIScreen.main, name: "EN_09_model400")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // Login page
        app.buttons["home_tab_settings"].tap()
        sleep(1)
        let loginButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Login")).firstMatch
        if loginButton.waitForExistence(timeout: 3) {
            loginButton.tap()
            sleep(2)
            save(XCUIScreen.main, name: "EN_10_login")
            let guest = app.buttons["login_guest_button"]
            if guest.waitForExistence(timeout: 3) { guest.tap() }
            sleep(1)
        }

        // Athlete editor copy in English
        app.buttons["home_tab_training"].tap()
        sleep(1)
        let hurdleAgain = app.buttons["mini_hurdle_open_button"]
        if hurdleAgain.waitForExistence(timeout: 4) {
            hurdleAgain.tap()
            sleep(2)
            let saveAthlete = anyElement(app, "mini_hurdle_athlete_save_button")
            if saveAthlete.waitForExistence(timeout: 3) {
                scrollUntilHittable(saveAthlete, in: app)
                saveAthlete.tap()
                sleep(1)
                save(XCUIScreen.main, name: "EN_11_athlete_editor")
                let cancelEditor = app.buttons["mini_hurdle_athlete_editor_cancel"]
                if cancelEditor.waitForExistence(timeout: 3) { cancelEditor.tap() }
                sleep(1)
            }
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        app.buttons["home_tab_settings"].tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Language")).firstMatch.tap()
        sleep(1)
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Chinese")).firstMatch.tap()
        sleep(1)
        if done.waitForExistence(timeout: 3) { done.tap() }
        sleep(1)
    }

    func testScreenshotExtendedPages() throws {
        let app = launchApp()
        sleep(2)

        // 1. Pace Run Editor & Active Training
        let paceBtn = app.buttons["pace_manage_button"]
        XCTAssertTrue(paceBtn.waitForExistence(timeout: 5))
        paceBtn.tap()
        sleep(1)

        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        if addPlan.waitForExistence(timeout: 3) {
            addPlan.tap()
            sleep(1)
            save(XCUIScreen.main, name: "10_pace_editor")

            let saveBtn = app.buttons["pace_editor_save_bar_button"]
            if saveBtn.waitForExistence(timeout: 3) {
                saveBtn.tap()
            }
            sleep(3)
        }

        let startPaceBtn = app.buttons["pace_start_training_button"]
        if startPaceBtn.waitForExistence(timeout: 5) {
            startPaceBtn.tap()
            sleep(5) // wait for 3s countdown to enter active running state
            if !app.buttons["停止"].exists && !app.buttons["Stop"].exists {
                startPaceBtn.tap()
                sleep(5)
            }
            save(XCUIScreen.main, name: "11_pace_training_active")

            // Stop training so a record is saved to History
            let stopBtn = app.buttons["停止"]
            if stopBtn.waitForExistence(timeout: 2) {
                stopBtn.tap()
            } else if app.buttons["Stop"].waitForExistence(timeout: 2) {
                app.buttons["Stop"].tap()
            }
            sleep(1)
            let confirmBtn = app.alerts.buttons["确定"]
            if confirmBtn.waitForExistence(timeout: 2) {
                confirmBtn.tap()
            } else if app.alerts.buttons["Confirm"].waitForExistence(timeout: 2) {
                app.alerts.buttons["Confirm"].tap()
            }
            sleep(1)
        }

        // Back to Home
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // 2. Interval Active Training
        let intervalBtn = app.buttons["interval_manage_button"]
        if intervalBtn.waitForExistence(timeout: 3) {
            intervalBtn.tap()
            sleep(1)
            let addInterval = app.buttons["interval_add_plan_toolbar_button"]
            if addInterval.waitForExistence(timeout: 3) {
                addInterval.tap()
                sleep(1)
                let saveBtn = app.buttons["interval_editor_save_bar_button"]
                if saveBtn.waitForExistence(timeout: 3) {
                    saveBtn.tap()
                }
                sleep(1)
            }
            let startIntervalBtn = app.buttons["interval_start_training_button"]
            if startIntervalBtn.waitForExistence(timeout: 3) {
                startIntervalBtn.tap()
                sleep(4)
                save(XCUIScreen.main, name: "12_interval_training_active")

                let stopBtn = app.buttons["停止"]
                if stopBtn.waitForExistence(timeout: 2) {
                    stopBtn.tap()
                } else if app.buttons["Stop"].waitForExistence(timeout: 2) {
                    app.buttons["Stop"].tap()
                }
                sleep(1)
                let confirmBtn = app.alerts.buttons["确定"]
                if confirmBtn.waitForExistence(timeout: 2) {
                    confirmBtn.tap()
                } else if app.alerts.buttons["Confirm"].waitForExistence(timeout: 2) {
                    app.alerts.buttons["Confirm"].tap()
                }
                sleep(1)
            }
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // 3. History with saved records
        let historyTab = app.buttons["home_tab_history"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            sleep(1)
            save(XCUIScreen.main, name: "14_history_with_records")
        }

        // 4. Model 400 scrolled to MetricTile summary
        let trainingTab = app.buttons["home_tab_training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
            sleep(1)
            let modelEntry = app.buttons["model_400_open_button"]
            if modelEntry.waitForExistence(timeout: 3) {
                modelEntry.tap()
                sleep(1)
                app.swipeUp()
                sleep(1)
                save(XCUIScreen.main, name: "13_model400_metrics")
            }
        }
    }

    func testScreenshotSecondaryPages() throws {
        let app = launchApp()
        sleep(2)

        // 1. Interval group editor
        let intervalBtn = app.buttons["interval_manage_button"]
        XCTAssertTrue(intervalBtn.waitForExistence(timeout: 5))
        intervalBtn.tap()
        sleep(1)

        let addInterval = app.buttons["interval_add_plan_toolbar_button"]
        if addInterval.waitForExistence(timeout: 3) {
            addInterval.tap()
            sleep(2)
            save(XCUIScreen.main, name: "15_interval_editor")

            // Cue palette inside the group editor: scroll the card into view,
            // then expand one cue row and capture the inline list.
            let cueRow = anyElement(app, "interval_cue_start_row")
            if cueRow.waitForExistence(timeout: 3) {
                var swipes = 0
                while !cueRow.isHittable && swipes < 10 {
                    app.swipeUp()
                    swipes += 1
                    sleep(1)
                }
                if cueRow.isHittable {
                    cueRow.tap()
                    sleep(2)
                }
                save(XCUIScreen.main, name: "25_interval_cue_palette")

                let pickerDone = app.buttons["sound_picker_done_button"]
                if pickerDone.waitForExistence(timeout: 3) { pickerDone.tap() }
                sleep(1)
            }

            let cancel = app.buttons["interval_editor_cancel_button"]
            if cancel.waitForExistence(timeout: 3) { cancel.tap() }
            sleep(1)
        }

        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // 2. Settings sheets: sound, language, login
        let settingsTab = app.buttons["home_tab_settings"]
        if settingsTab.waitForExistence(timeout: 3) {
            settingsTab.tap()
            sleep(1)

            let soundRow = app.staticTexts["提示音设置"]
            if soundRow.waitForExistence(timeout: 3) {
                soundRow.tap()
                sleep(2)
                save(XCUIScreen.main, name: "16_sound_settings")

                app.swipeUp()
                sleep(1)
                app.swipeUp()
                sleep(1)
                save(XCUIScreen.main, name: "27_sound_library")

                let done = app.buttons["sound_settings_done_button"]
                if done.waitForExistence(timeout: 3) { done.tap() }
                sleep(1)
            }

            let languageRow = app.staticTexts["语言设置"]
            if languageRow.waitForExistence(timeout: 3) {
                languageRow.tap()
                sleep(2)
                save(XCUIScreen.main, name: "17_language_settings")

                let done = app.buttons["language_settings_done_button"]
                if done.waitForExistence(timeout: 3) { done.tap() }
                sleep(1)
            }

            let loginBtn = app.buttons["settings_login_button"]
            if loginBtn.waitForExistence(timeout: 3) {
                loginBtn.tap()
                sleep(2)
                save(XCUIScreen.main, name: "18_login")

                let guest = app.buttons["login_guest_button"]
                if guest.waitForExistence(timeout: 3) { guest.tap() }
                sleep(1)
            }
        }

        // 3. Mini hurdle: athlete editor, athlete list, reference disclosures
        let trainingTab = app.buttons["home_tab_training"]
        if trainingTab.waitForExistence(timeout: 3) {
            trainingTab.tap()
            sleep(1)

            let hurdleEntry = app.buttons["mini_hurdle_open_button"]
            XCTAssertTrue(hurdleEntry.waitForExistence(timeout: 5))
            hurdleEntry.tap()
            sleep(2)

            // Athlete editor sheet — 保存动作在第三步末尾，可能需要先滚到可视区
            let saveAthlete = anyElement(app, "mini_hurdle_athlete_save_button")
            if saveAthlete.waitForExistence(timeout: 3) {
                scrollUntilHittable(saveAthlete, in: app)
                saveAthlete.tap()
                sleep(1)
                let nameField = app.textFields["mini_hurdle_athlete_name_textfield"]
                if nameField.waitForExistence(timeout: 3) {
                    nameField.tap()
                    nameField.typeText("李冠华")
                }
                sleep(1)
                save(XCUIScreen.main, name: "19_athlete_editor")

                let saveButton = anyElement(app, "mini_hurdle_athlete_editor_save")
                if saveButton.waitForExistence(timeout: 3) { saveButton.tap() }
                sleep(2)

                // Step 01 with a saved athlete selected.
                app.swipeDown()
                app.swipeDown()
                app.swipeDown()
                sleep(1)
                save(XCUIScreen.main, name: "29_hurdle_athlete_selected")
            }

            // Athlete list sheet (visible once one athlete exists)
            let listBtn = anyElement(app, "mini_hurdle_athlete_list_button")
            if listBtn.waitForExistence(timeout: 3) {
                listBtn.tap()
                sleep(2)
                save(XCUIScreen.main, name: "20_athlete_list")

                let close = app.buttons["取消"].firstMatch
                if close.waitForExistence(timeout: 2) { close.tap() }
                sleep(1)
            }

            // Reference disclosures at the bottom of the page
            let referenceRow = anyElement(app, "mini_hurdle_measurement_detail_toggle")
            scrollUntilHittable(referenceRow, in: app)
            if referenceRow.exists {
                referenceRow.tap()
                sleep(1)
                app.swipeUp()
                sleep(1)
                save(XCUIScreen.main, name: "21_reference_definition")

                let diagramRow = anyElement(app, "mini_hurdle_measurement_illustration_toggle")
                scrollUntilHittable(diagramRow, in: app)
                if diagramRow.exists {
                    diagramRow.tap()
                    sleep(1)
                    scrollUntilHittable(anyElement(app, "mini_hurdle_measurement_diagram"), in: app, maxSwipes: 4)
                    save(XCUIScreen.main, name: "22_reference_diagram")
                }

                let methodRow = anyElement(app, "mini_hurdle_method_detail_toggle_id")
                scrollUntilHittable(methodRow, in: app)
                if methodRow.exists {
                    methodRow.tap()
                    sleep(1)
                    save(XCUIScreen.main, name: "23_reference_method")
                }

                let qualityRow = anyElement(app, "mini_hurdle_quality_detail_toggle")
                scrollUntilHittable(qualityRow, in: app)
                if qualityRow.exists {
                    qualityRow.tap()
                    sleep(1)
                    save(XCUIScreen.main, name: "24_reference_quality")
                }
            }
        }
    }
    /// Captures the session shell on a wide canvas (unfolded foldable / iPad):
    /// the timing column and the upcoming-work column should render side by side.
    func testWideSessionLayoutOnRegularWidth() throws {
        let app = launchApp()
        sleep(2)

        let pace = app.buttons["pace_manage_button"]
        XCTAssertTrue(pace.waitForExistence(timeout: 5))
        pace.tap()
        sleep(1)
        save(XCUIScreen.main, name: "wide_pace_setup")

        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        if addPlan.waitForExistence(timeout: 3) {
            addPlan.tap()
            sleep(1)
            let saveBtn = app.buttons["pace_editor_save_bar_button"]
            if saveBtn.waitForExistence(timeout: 3) { saveBtn.tap() }
            sleep(2)
        }

        let start = app.buttons["pace_start_training_button"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        sleep(9)
        save(XCUIScreen.main, name: "wide_pace_training")

        let stopBtn = app.buttons["停止"].exists ? app.buttons["停止"] : app.buttons["Stop"]
        if stopBtn.exists { stopBtn.tap() }
        sleep(1)
        let confirm = app.alerts.buttons["确定"].exists ? app.alerts.buttons["确定"] : app.alerts.buttons["Confirm"]
        if confirm.exists { confirm.tap() }
    }

}

import XCTest

final class RunningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    private func launchApp(
        language: String = "en",
        locale: String = "en_US",
        additionalArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-AppleLanguages",
            "(\(language))",
            "-AppleLocale",
            locale,
            "-app_language",
            language
        ]
        app.launchArguments += additionalArguments
        app.launch()
        return app
    }

    private func captureReferenceScreenshot(
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Best-effort file copy: the attachment above is authoritative.
        // Device sandboxes deny arbitrary /tmp paths, so write into the
        // runner's own temporary directory and never fail the test on IO.
        let screenshotsDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("mini-hurdle-ui", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
            let screenshotURL = screenshotsDirectory.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: screenshotURL)
        } catch {
            // Intentionally non-fatal — see note above.
        }
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
        XCTAssertTrue(waitUntil(timeout: 10) { manage.exists && manage.isHittable })
        manage.tap()
        XCTAssertTrue(app.buttons["pace_add_plan_toolbar_button"].waitForExistence(timeout: 10))
    }

    private func addDefaultPaceGroup(_ app: XCUIApplication) {
        let addPlan = app.buttons["pace_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.buttons["pace_editor_save_bar_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
    }

    private func openIntervalTrainingPlans(_ app: XCUIApplication) {
        let manage = app.buttons["interval_manage_button"]
        XCTAssertTrue(waitUntil(timeout: 10) { manage.exists && manage.isHittable })
        manage.tap()
        XCTAssertTrue(app.buttons["interval_add_plan_toolbar_button"].waitForExistence(timeout: 10))
    }

    private func addDefaultIntervalGroup(_ app: XCUIApplication) {
        let addPlan = app.buttons["interval_add_plan_toolbar_button"]
        XCTAssertTrue(addPlan.waitForExistence(timeout: 3))
        addPlan.tap()

        let save = app.buttons["interval_editor_save_bar_button"]
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

    private func openMiniHurdleModule(_ app: XCUIApplication) {
        let miniHurdleEntry = app.buttons["mini_hurdle_open_button"]
        XCTAssertTrue(miniHurdleEntry.waitForExistence(timeout: 5))
        miniHurdleEntry.tap()
        XCTAssertTrue(app.scrollViews["mini_hurdle_scroll"].waitForExistence(timeout: 3))
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.tap()

        if let currentValue = element.value as? String,
           currentValue.isEmpty == false,
           currentValue != element.placeholderValue {
            let deleteSequence = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteSequence)
        }

        element.typeText(text)
    }

    private func waitForLabel(
        of element: XCUIElement,
        equals expectedLabel: String,
        timeout: TimeInterval = 3
    ) -> Bool {
        waitUntil(timeout: timeout) {
            element.exists && element.label == expectedLabel
        }
    }

    private func scrollToTop(_ scrollView: XCUIElement) {
        for _ in 0..<5 {
            scrollView.swipeDown()
        }
    }

    private func makeElementHittable(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        swipingUp maxSwipes: Int = 6
    ) {
        if element.waitForExistence(timeout: 1), element.isHittable {
            return
        }

        for _ in 0..<maxSwipes {
            scrollView.swipeUp()
            if element.waitForExistence(timeout: 1), element.isHittable {
                return
            }
        }
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

        // iPad: the confirm tap can land inside the keyboard-hide animation
        // window and get swallowed — retry until the sheet actually leaves.
        var confirmAttempts = 1
        while floatingInputConfirm.exists && confirmAttempts < 4 {
            confirmAttempts += 1
            floatingInputConfirm.tap()
            _ = waitUntil(timeout: 3) { !floatingInputConfirm.exists }
        }
        let sheetDismissed = !floatingInputConfirm.exists
        if !sheetDismissed {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "floating-sheet-still-up"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(sheetDismissed, "Floating input sheet did not dismiss after \(confirmAttempts) confirm taps")

        let generateButton = app.buttons["model_400_generate_button"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3))
        // Landscape iPad may keep the CTA below the fold — bring it on
        // screen before tapping (off-screen taps silently do nothing).
        var generateScrollAttempts = 0
        while !generateButton.isHittable && generateScrollAttempts < 6 {
            app.swipeUp()
            generateScrollAttempts += 1
        }
        XCTAssertTrue(
            generateButton.isHittable,
            "Generate CTA not hittable: frame=\(generateButton.frame) window=\(app.frame) swipes=\(generateScrollAttempts)"
        )
        generateButton.tap()

        // Audit A3 flow: generation stays on this page and confirms with a
        // banner; navigation happens through its "View" action.
        let viewPlanButton = app.buttons["model_400_view_plan_button"]
        let bannerAppeared = viewPlanButton.waitForExistence(timeout: 5)
        if !bannerAppeared {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "generate-no-banner"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(bannerAppeared)
        viewPlanButton.tap()

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

        // iPad: the confirm tap can land inside the keyboard-hide animation
        // window and get swallowed — retry until the sheet actually leaves.
        var confirmAttempts = 1
        while floatingInputConfirm.exists && confirmAttempts < 4 {
            confirmAttempts += 1
            floatingInputConfirm.tap()
            _ = waitUntil(timeout: 3) { !floatingInputConfirm.exists }
        }
        XCTAssertTrue(!floatingInputConfirm.exists, "Floating input sheet did not dismiss after \(confirmAttempts) confirm taps")

        let generateButton = app.buttons["model_400_generate_button"]
        XCTAssertTrue(generateButton.waitForExistence(timeout: 3))
        // Landscape iPad may keep the CTA below the fold — bring it on
        // screen before tapping (off-screen taps silently do nothing).
        var generateScrollAttempts = 0
        while !generateButton.isHittable && generateScrollAttempts < 6 {
            app.swipeUp()
            generateScrollAttempts += 1
        }
        generateButton.tap()

        // Audit A3 flow: the banner confirms generation; follow it to the
        // pace list and assert the generated plan name there. On device the
        // app can stay busy (CloudKit, haptics) — retry the tap if the
        // banner does not surface in time.
        let viewPlanButton = app.buttons["model_400_view_plan_button"]
        var bannerAppeared = viewPlanButton.waitForExistence(timeout: 5)
        var generateTaps = 1
        while !bannerAppeared && generateTaps < 3 {
            generateTaps += 1
            if generateButton.isHittable { generateButton.tap() }
            bannerAppeared = viewPlanButton.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(bannerAppeared, "Generation banner did not appear after \(generateTaps) generate taps")
        // A busy device can delay event delivery past the banner's 5s
        // auto-hide — re-check and re-generate if it expired before the tap.
        if !viewPlanButton.exists {
            if generateButton.isHittable { generateButton.tap() }
            XCTAssertTrue(viewPlanButton.waitForExistence(timeout: 5))
        }
        viewPlanButton.tap()

        let generatedTitle = app.staticTexts["Women 400m 50.00 - 50m"]
        XCTAssertTrue(generatedTitle.waitForExistence(timeout: 5))
    }

    func testMiniHurdleModuleRendersInChineseAndCapturesReferenceScreens() throws {
        let app = launchApp(language: "zh-Hans", locale: "zh_CN")

        let miniHurdleEntry = app.buttons["mini_hurdle_open_button"]
        XCTAssertTrue(miniHurdleEntry.waitForExistence(timeout: 5))
        miniHurdleEntry.tap()

        XCTAssertTrue(app.navigationBars.staticTexts["小栏架栏距"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["mini_hurdle_scroll"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["选择运动员"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["GT 下肢长（大转子高度）"].waitForExistence(timeout: 3))

        captureReferenceScreenshot(name: "mini-hurdle-top")

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        scrollView.swipeUp()

        XCTAssertTrue(app.staticTexts["摆点方案"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["本次摆栏结果"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2.02 米"].waitForExistence(timeout: 3))

        captureReferenceScreenshot(name: "mini-hurdle-middle")

        scrollView.swipeUp()
        scrollView.swipeUp()

        XCTAssertTrue(app.staticTexts["加栏顺序"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["调距判断"].waitForExistence(timeout: 3))

        captureReferenceScreenshot(name: "mini-hurdle-bottom")
    }

    func testMiniHurdleModuleStagesVisualInspectionInChinese() throws {
        let app = launchApp(language: "zh-Hans", locale: "zh_CN")

        let miniHurdleEntry = app.buttons["mini_hurdle_open_button"]
        XCTAssertTrue(miniHurdleEntry.waitForExistence(timeout: 5))
        miniHurdleEntry.tap()

        XCTAssertTrue(app.staticTexts["选择运动员"].waitForExistence(timeout: 8))
        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        sleep(4)
        scrollView.swipeUp()
        XCTAssertTrue(app.staticTexts["本次摆栏结果"].waitForExistence(timeout: 5))

        sleep(4)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertTrue(app.staticTexts["调距判断"].waitForExistence(timeout: 5))

        sleep(4)
    }

    func testMiniHurdleDirectLaunchStagesVisualInspectionInChinese() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-AppleLanguages",
            "(zh-Hans)",
            "-AppleLocale",
            "zh_CN",
            "-app_language",
            "zh-Hans"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["选择运动员"].waitForExistence(timeout: 8))
        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))

        sleep(5)
        scrollView.swipeUp()
        XCTAssertTrue(app.staticTexts["本次摆栏结果"].waitForExistence(timeout: 5))

        sleep(5)
        scrollView.swipeUp()
        scrollView.swipeUp()
        XCTAssertTrue(app.staticTexts["调距判断"].waitForExistence(timeout: 5))

        sleep(5)
    }

    func testMiniHurdleMeasurementReferenceCapturesUpperAndLowerScreens() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-ui_testing_mini_hurdle_section",
            "measurement",
            "-AppleLanguages",
            "(zh-Hans)",
            "-AppleLocale",
            "zh_CN",
            "-app_language",
            "zh-Hans"
        ]
        app.launch()

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["方法与依据"].waitForExistence(timeout: 5))

        // Audit MH-10: expand the collapsed diagram before asserting it.
        let illustrationToggle = app.buttons["mini_hurdle_measurement_illustration_toggle"]
        XCTAssertTrue(illustrationToggle.waitForExistence(timeout: 5))
        illustrationToggle.tap()
        XCTAssertTrue(app.images["mini_hurdle_measurement_full_image"].waitForExistence(timeout: 5))

        captureReferenceScreenshot(name: "mini-hurdle-measurement-upper")

        let detailToggle = app.buttons["mini_hurdle_measurement_detail_toggle"]
        XCTAssertTrue(detailToggle.waitForExistence(timeout: 3))
        detailToggle.tap()

        XCTAssertTrue(app.staticTexts["GT 测量口径"].waitForExistence(timeout: 5))
        captureReferenceScreenshot(name: "mini-hurdle-measurement-lower")
    }

    func testMiniHurdleMeasurementDiagramIsDirectAndActionable() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-ui_testing_mini_hurdle_section",
            "measurement",
            "-AppleLanguages",
            "(zh-Hans)",
            "-AppleLocale",
            "zh_CN",
            "-app_language",
            "zh-Hans"
        ]
        app.launch()

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        // Audit MH-10: the diagram now lives behind an opt-in disclosure —
        // expand it, then assert the diagram is rendered and actionable.
        let illustrationToggle = app.buttons["mini_hurdle_measurement_illustration_toggle"]
        XCTAssertTrue(illustrationToggle.waitForExistence(timeout: 5))
        illustrationToggle.tap()

        XCTAssertTrue(app.images["mini_hurdle_measurement_full_image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["mini_hurdle_gt_marker"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["mini_hurdle_vertical_measure_line"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["mini_hurdle_measurement_detail_toggle"].waitForExistence(timeout: 3))
    }

    func testMiniHurdleMainTableMatchesWorkbookCumulativeCoordinates() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-ui_testing_mini_hurdle_section",
            "hurdles",
            "-AppleLanguages",
            "(zh-Hans)",
            "-AppleLocale",
            "zh_CN",
            "-app_language",
            "zh-Hans"
        ]
        app.launch()

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["现场摆放表"].waitForExistence(timeout: 5))

        let firstPoint = app.staticTexts["mini_hurdle_point_1"]
        let firstSpacing = app.staticTexts["mini_hurdle_spacing_1"]
        let lastPoint = app.staticTexts["mini_hurdle_point_21"]

        XCTAssertTrue(firstPoint.waitForExistence(timeout: 5))
        XCTAssertTrue(firstSpacing.waitForExistence(timeout: 5))
        XCTAssertTrue(lastPoint.waitForExistence(timeout: 5))

        XCTAssertEqual(firstPoint.label, "10.155")
        XCTAssertEqual(firstSpacing.label, "1.61 米")
        XCTAssertEqual(lastPoint.label, "47.905")
    }

    func testMiniHurdleMainTableShowsContinuousExcelChainFromStartThroughAccMarks() throws {
        let app = XCUIApplication()
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-ui_testing_mini_hurdle_section",
            "hurdles",
            "-AppleLanguages",
            "(zh-Hans)",
            "-AppleLocale",
            "zh_CN",
            "-app_language",
            "zh-Hans"
        ]
        app.launch()

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let startPoint = app.staticTexts["mini_hurdle_sequence_point_0"]
        let acc7Point = app.staticTexts["mini_hurdle_sequence_point_7"]
        let hurdle1Point = app.staticTexts["mini_hurdle_point_1"]

        XCTAssertTrue(startPoint.waitForExistence(timeout: 5))
        XCTAssertTrue(acc7Point.waitForExistence(timeout: 5))
        XCTAssertTrue(hurdle1Point.waitForExistence(timeout: 5))

        XCTAssertEqual(startPoint.label, "0.00")
        XCTAssertEqual(acc7Point.label, "8.545")
        XCTAssertEqual(hurdle1Point.label, "10.155")

        captureReferenceScreenshot(name: "mini-hurdle-hurdles-chain")
    }

    func testMiniHurdleAthleteProfilesSupportSaveSwitchRenameAndDelete() throws {
        let app = launchApp(
            language: "zh-Hans",
            locale: "zh_CN",
            additionalArguments: [
                "-ui_testing_open_mini_hurdle",
                "-ui_testing_seed_mini_hurdle",
                "athleteProfiles"
            ]
        )
        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let currentAthleteName = app.staticTexts["mini_hurdle_current_athlete_name"]
        XCTAssertTrue(waitForLabel(of: currentAthleteName, equals: "AthleteB"))

        let switchButton = app.buttons["mini_hurdle_athlete_switch_button"]
        XCTAssertTrue(switchButton.waitForExistence(timeout: 3))
        switchButton.tap()

        let firstAthleteRow = app.buttons["mini_hurdle_athlete_picker_name_AthleteA"]
        XCTAssertTrue(firstAthleteRow.waitForExistence(timeout: 3))
        firstAthleteRow.tap()

        XCTAssertTrue(waitForLabel(of: currentAthleteName, equals: "AthleteA"))

        let manageButton = app.buttons["mini_hurdle_athlete_manage_button"]
        XCTAssertTrue(manageButton.waitForExistence(timeout: 3))
        manageButton.tap()

        let editorSaveButton = app.buttons["mini_hurdle_athlete_editor_save"]
        XCTAssertTrue(editorSaveButton.waitForExistence(timeout: 3))
        // 删除按钮位于编辑器表单底部，懒渲染需先滚动到可视区域
        app.swipeUp()

        let deleteButton = app.buttons["mini_hurdle_athlete_delete_button"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let deleteConfirmButton = app.buttons.matching(identifier: "mini_hurdle_athlete_delete_confirm").firstMatch
        XCTAssertTrue(deleteConfirmButton.waitForExistence(timeout: 3))
        deleteConfirmButton.tap()

        XCTAssertTrue(waitForLabel(of: currentAthleteName, equals: "AthleteB"))
    }

    func testTemporaryHurdleInputAndSavedAthleteStayIndependent() throws {
        let app = launchApp(additionalArguments: ["-ui_testing_open_mini_hurdle"])
        let scroll = app.scrollViews["mini_hurdle_scroll"]
        let gt = app.textFields["mini_hurdle_gt_input"]
        XCTAssertTrue(gt.waitForExistence(timeout: 5))
        let clear = app.buttons["mini_hurdle_clear_gt"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        gt.tap()
        clear.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !clear.isEnabled })
        gt.typeText("86.75")
        XCTAssertEqual(gt.value as? String, "86.75")
        XCTAssertTrue(app.staticTexts["Calculated as 0.8675 m."].exists)
        let done = app.buttons["mini_hurdle_gt_done"]
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertFalse(done.exists)
        app.buttons["m"].tap()
        XCTAssertEqual(gt.value as? String, "0.8675")

        let save = app.buttons["mini_hurdle_athlete_save_button"]
        makeElementHittable(save, in: scroll)
        save.tap()
        let name = app.textFields["mini_hurdle_athlete_name_textfield"]
        replaceText(in: name, with: "Track A")
        app.buttons["mini_hurdle_athlete_editor_save"].tap()

        scrollToTop(scroll)
        let increase = app.buttons["mini_hurdle_gt_step_up"]
        XCTAssertTrue(increase.waitForExistence(timeout: 3))
        increase.tap()
        XCTAssertEqual(gt.value as? String, "0.8775")
        app.buttons["Temporary"].tap()
        XCTAssertEqual(gt.value as? String, "0.8675")

        app.buttons["Saved athlete"].tap()
        app.buttons["mini_hurdle_list_edit_Track A"].tap()
        let editor = app.scrollViews.containing(.textField, identifier: "mini_hurdle_editor_gt_input").firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.buttons["cm"].tap()
        XCTAssertEqual(editor.textFields["mini_hurdle_editor_gt_input"].value as? String, "87.75")
        app.buttons["mini_hurdle_athlete_editor_cancel"].tap()
        XCTAssertEqual(gt.value as? String, "0.8675")
        app.buttons["Saved athlete"].tap()
        app.buttons["mini_hurdle_list_select_Track A"].tap()
        XCTAssertEqual(gt.value as? String, "0.8775")

        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui_testing_reset" }
        app.launch()
        XCTAssertTrue(gt.waitForExistence(timeout: 5))
        XCTAssertEqual(gt.value as? String, "0.8775")
        XCTAssertTrue(app.buttons["mini_hurdle_athlete_manage_button"].exists)
    }

    func testIncompleteHurdleMeasurementPreservesTheSavedAthlete() throws {
        let app = launchApp(additionalArguments: ["-ui_testing_open_mini_hurdle", "-ui_testing_seed_mini_hurdle", "athleteProfiles"])
        let gt = app.textFields["mini_hurdle_gt_input"]
        XCTAssertTrue(gt.waitForExistence(timeout: 5))
        XCTAssertEqual(gt.value as? String, "92")
        let clear = app.buttons["mini_hurdle_clear_gt"]
        gt.tap()
        clear.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !clear.isEnabled })
        gt.typeText("1")
        XCTAssertEqual(gt.value as? String, "1")
        let saveEnabled = app.buttons["mini_hurdle_athlete_save_button"].isEnabled

        app.terminate()
        app.launchArguments.removeAll { ["-ui_testing_reset", "-ui_testing_seed_mini_hurdle", "athleteProfiles"].contains($0) }
        app.launch()
        XCTAssertTrue(gt.waitForExistence(timeout: 5))
        XCTAssertEqual(gt.value as? String, "92")
        XCTAssertFalse(saveEnabled)
    }

    func testLandscapePaceControlsAlignWithTimer() throws {
        try verifyLandscapeControls(forPace: true, orientation: .landscapeLeft)
    }

    func testLandscapeIntervalControlsAlignWithTimer() throws {
        try verifyLandscapeControls(forPace: false, orientation: .landscapeRight)
    }

    func testConvertingToCustomPaceSegmentsPreservesTheTotalDistance() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        app.buttons["pace_add_plan_toolbar_button"].tap()
        let scroll = app.scrollViews.firstMatch
        let total = app.buttons["pace_total_distance_1500"].firstMatch
        makeElementHittable(total, in: scroll)
        total.tap()
        let split = app.buttons["pace_segment_distance_200"].firstMatch
        makeElementHittable(split, in: scroll)
        split.tap()
        let custom = app.buttons["Custom Segments"].firstMatch
        makeElementHittable(custom, in: scroll)
        custom.tap()
        app.buttons["pace_editor_save_bar_button"].tap()

        XCTAssertTrue(app.staticTexts["1500m"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["1600m"].exists)
    }

    private func verifyLandscapeControls(forPace: Bool, orientation: UIDeviceOrientation) throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone)
        XCUIDevice.shared.press(.home)
        XCUIDevice.shared.orientation = .portrait
        let app = launchApp()
        defer {
            XCUIDevice.shared.orientation = .portrait
            _ = waitUntil(timeout: 8) { app.frame.height > app.frame.width }
            XCUIDevice.shared.press(.home)
        }
        let prefix = forPace ? "pace" : "interval"
        let addGroup = forPace ? addDefaultPaceGroup : addDefaultIntervalGroup
        if forPace { openPaceTrainingPlans(app) } else { openIntervalTrainingPlans(app) }
        addGroup(app)
        let start = app.buttons["\(prefix)_start_training_button"]
        let groupPauses = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Pause", "training_pause_resume"))
        start.tap()
        XCTAssertTrue(groupPauses.firstMatch.waitForExistence(timeout: 12))
        stopActiveTraining(app)
        addGroup(app)
        XCTAssertTrue(waitUntil(timeout: 5) { start.isEnabled && start.isHittable })
        start.tap()
        XCUIDevice.shared.orientation = orientation
        let globalPause = app.buttons["training_pause_resume"]
        let stop = app.buttons["Stop"]

        func checkAlignment(name: String) {
            XCTAssertTrue(groupPauses.firstMatch.waitForExistence(timeout: 10))
            let viewport = app.scrollViews.firstMatch.frame
            XCTAssertLessThanOrEqual(viewport.maxY, globalPause.frame.minY + 1)
            XCTAssertEqual(stop.frame.maxX - groupPauses.firstMatch.frame.maxX, 20, accuracy: 2)
            XCTAssertEqual(globalPause.frame.midY, stop.frame.midY, accuracy: 1)
            XCTAssertGreaterThanOrEqual(globalPause.frame.height, 44)
            captureReferenceScreenshot(name: name)
            globalPause.tap()
            XCTAssertEqual(globalPause.label, "Resume")
            XCTAssertTrue(app.staticTexts["Paused"].firstMatch.waitForExistence(timeout: 3))
            globalPause.tap()
            XCTAssertEqual(globalPause.label, "Pause")
            stopActiveTraining(app)
            XCTAssertTrue(waitUntil(timeout: 8) { start.isHittable && !stop.exists })
        }

        checkAlignment(name: "\(prefix)-landscape-single")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(waitUntil(timeout: 5) { app.frame.height > app.frame.width })
        let history = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", "\(prefix)_setup_tab_picker", "History")).firstMatch
        history.tap()
        let plans = app.staticTexts.matching(identifier: "New Group")
        XCTAssertTrue(waitUntil(timeout: 4) { plans.count == 2 })
        // Starting the second plan selects it. Add the older plan to launch both.
        plans.element(boundBy: 1).tap()
        XCTAssertTrue(start.label.contains("(2)"))
        start.tap()
        XCUIDevice.shared.orientation = orientation
        XCTAssertTrue(app.staticTexts["PLAN 1"].waitForExistence(timeout: 10))
        checkAlignment(name: "\(prefix)-landscape-multiple")
    }

    func testPausingPreparationKeepsTheCountdownAcrossHome() throws {
        let app = launchApp()
        openPaceTrainingPlans(app)
        addDefaultPaceGroup(app)
        app.buttons["10s"].tap()
        app.buttons["pace_start_training_button"].tap()
        let pause = app.buttons["training_pause_resume"]
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        pause.tap()

        let seconds = app.staticTexts["training_preparation_seconds"]
        XCTAssertTrue(seconds.exists)
        let frozen = seconds.label
        XCUIDevice.shared.press(.home)
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        app.activate()
        XCTAssertTrue(pause.waitForExistence(timeout: 3))
        XCTAssertEqual(pause.label, "Resume")
        XCTAssertEqual(seconds.label, frozen)

        pause.tap()
        XCTAssertTrue(waitUntil(timeout: 12) {
            !seconds.exists
        })
        pause.tap()
        XCTAssertTrue(app.staticTexts["Paused"].firstMatch.waitForExistence(timeout: 3))
        stopActiveTraining(app)
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

        let save = app.buttons["pace_editor_save_bar_button"]
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

        let save = app.buttons["interval_editor_save_bar_button"]
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

        let historyTab = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "pace_setup_tab_picker", "History")
        ).firstMatch
        XCTAssertTrue(historyTab.waitForExistence(timeout: 3))
        historyTab.tap()

        let historyTitles = app.staticTexts.matching(identifier: "New Group")
        XCTAssertTrue(waitUntil(timeout: 3) { historyTitles.count == 1 })
        historyTitles.firstMatch.swipeLeft()

        let edit = app.buttons["pace_history_edit_button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()

        let createTab = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label == %@", "pace_setup_tab_picker", "Create")
        ).firstMatch
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

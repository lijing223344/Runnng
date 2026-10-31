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
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

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
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)
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
    }
}

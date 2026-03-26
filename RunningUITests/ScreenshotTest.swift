import XCTest

final class ScreenshotTest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        if app.state != .notRunning { app.terminate() }
        app.launchArguments += ["-ui_testing_reset", "-ui_testing_disable_sound", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN", "-app_language", "zh-Hans"]
        app.launch()
        return app
    }

    private var devicePrefix: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }

    private func save(_ screen: XCUIScreenshot, name: String) {
        let data = screen.pngRepresentation
        let url = URL(fileURLWithPath: "/Users/lgh/Documents/Running/output/\(devicePrefix)_\(name).png")
        try? data.write(to: url)
    }

    func testScreenshotAllPages() throws {
        let app = launchApp()
        sleep(2)

        // 1. Home
        save(XCUIScreen.main.screenshot(), name: "01_home")

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
        save(XCUIScreen.main.screenshot(), name: "02_pace_setup")

        // Back to home
        app.navigationBars.buttons.firstMatch.tap()
        sleep(1)

        // 3. Interval Setup with a group
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
            save(XCUIScreen.main.screenshot(), name: "03_interval_setup")
        }
    }
}

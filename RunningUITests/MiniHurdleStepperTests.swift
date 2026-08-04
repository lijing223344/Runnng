import XCTest

final class MiniHurdleStepperTests: XCTestCase {
    func testGTStepperAdjustsValue() throws {
        let app = XCUIApplication()
        if app.state != .notRunning { app.terminate() }
        app.launchArguments += [
            "-ui_testing_reset",
            "-ui_testing_disable_sound",
            "-ui_testing_open_mini_hurdle",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN",
            "-app_language", "zh-Hans"
        ]
        app.launch()

        let scrollView = app.scrollViews["mini_hurdle_scroll"]
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5))

        let field = app.textFields["mini_hurdle_gt_input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "86")

        let stepUp = app.buttons["mini_hurdle_gt_step_up"]
        let stepDown = app.buttons["mini_hurdle_gt_step_down"]
        XCTAssertTrue(stepUp.waitForExistence(timeout: 3))

        stepUp.tap()
        XCTAssertEqual(field.value as? String, "87")

        stepDown.tap()
        stepDown.tap()
        XCTAssertEqual(field.value as? String, "85")

        // 结果区应随步进联动刷新（87 cm -> 2.05 米最长栏距）
        stepUp.tap()
        stepUp.tap()
        XCTAssertTrue(app.staticTexts["本次摆栏结果"].waitForExistence(timeout: 3))
    }
}

import XCTest

final class WidgetSetupUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testInstallTimeNestWidget() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--timenest-screenshot-scene", "month_view"]
        app.launch()

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))

        let appSwitcher = springboard.otherElements["AppSwitcherContentView"]
        if appSwitcher.waitForExistence(timeout: 2) {
            XCUIDevice.shared.press(.home)
            XCTAssertFalse(
                appSwitcher.waitForExistence(timeout: 2),
                "Unable to leave the App Switcher for the Home Screen."
            )
        }

        let emptyArea = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.72))
        emptyArea.press(forDuration: 2.0)

        if springboard.buttons["Edit"].waitForExistence(timeout: 2) {
            springboard.buttons["Edit"].tap()
        } else if springboard.buttons["編集"].waitForExistence(timeout: 2) {
            springboard.buttons["編集"].tap()
        } else if springboard.buttons["编辑"].waitForExistence(timeout: 2) {
            springboard.buttons["编辑"].tap()
        }

        let addWidgetLabels = ["Add Widget", "ウィジェットを追加", "添加小组件"]
        if let label = addWidgetLabels.first(where: { springboard.buttons[$0].waitForExistence(timeout: 1) }) {
            springboard.buttons[label].tap()
        } else {
            let addButtons = springboard.buttons.matching(NSPredicate(
                format: "label IN %@",
                ["Add", "追加", "添加", "plus", "追加ボタン"]
            ))
            guard addButtons.firstMatch.waitForExistence(timeout: 2) else {
                XCTFail("Unable to open the Widget gallery. SpringBoard hierarchy:\n\(springboard.debugDescription)")
                return
            }
            addButtons.firstMatch.tap()
        }

        let searchField = springboard.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 5),
            "Widget search field did not appear. SpringBoard hierarchy:\n\(springboard.debugDescription)"
        )
        searchField.tap()
        searchField.typeText("TimeNest")

        let result = springboard.cells["TimeNest"].firstMatch
        XCTAssertTrue(
            result.waitForExistence(timeout: 5),
            "TimeNest did not appear in Widget search. SpringBoard hierarchy:\n\(springboard.debugDescription)"
        )
        result.tap()

        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.91)).tap()

        for doneLabel in ["Done", "完了", "完成"] where springboard.buttons[doneLabel].waitForExistence(timeout: 1) {
            springboard.buttons[doneLabel].tap()
            return
        }
    }
}

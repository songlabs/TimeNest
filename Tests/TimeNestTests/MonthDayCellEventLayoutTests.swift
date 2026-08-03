import XCTest
@testable import TimeNest

final class MonthDayCellEventLayoutTests: XCTestCase {
    func testUpToFourItemsRemainVisibleInTheirOriginalOrder() {
        for count in 0...4 {
            let items = Array(0..<count)
            let visibility = MonthDayCellEventLayout.visibility(for: items)

            XCTAssertEqual(visibility.visibleItems, items)
            XCTAssertEqual(visibility.hiddenCount, 0)
        }
    }

    func testFourItemsDoNotCreateOverflow() {
        let items = ["shift", "event-a", "work-record", "event-b"]

        let visibility = MonthDayCellEventLayout.visibility(for: items)

        XCTAssertEqual(visibility.visibleItems, items)
        XCTAssertEqual(visibility.hiddenCount, 0)
    }

    func testFiveItemsKeepTheFirstThreeAndSummarizeTheRemainingTwo() {
        let items = ["first", "second", "third", "fourth", "fifth"]

        let visibility = MonthDayCellEventLayout.visibility(for: items)

        XCTAssertEqual(visibility.visibleItems, ["first", "second", "third"])
        XCTAssertEqual(visibility.hiddenCount, 2)
    }
}

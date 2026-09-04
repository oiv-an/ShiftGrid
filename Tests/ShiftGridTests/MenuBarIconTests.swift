import XCTest
@testable import ShiftGrid

final class MenuBarIconTests: XCTestCase {
    func testMenuBarIconIsAVisibleTemplateImage() {
        let image = MenuBarIcon.make()

        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.accessibilityDescription, "ShiftGrid")
    }
}

import Foundation
import XCTest
@testable import ShiftGrid

final class AppPreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ShiftGridTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testHoldAndReleaseIsDefaultSelectionMethod() {
        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.selectionMethod, .holdShiftAndRelease)
    }

    func testClickSelectionMethodRoundTrips() {
        let preferences = AppPreferences(defaults: defaults)

        preferences.selectionMethod = .click

        XCTAssertEqual(preferences.selectionMethod, .click)
    }

    func testInvalidSelectionMethodFallsBackToHoldAndRelease() {
        defaults.set("invalid", forKey: "selectionMethod")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.selectionMethod, .holdShiftAndRelease)
    }

    func testAddingSelectionMethodPreservesExistingLayoutPreferences() {
        defaults.set(2, forKey: "layoutDefaultsRevision")
        defaults.set(ColumnMode.three.rawValue, forKey: "columnMode")
        defaults.set(15, forKey: "spacing")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.selectionMethod, .holdShiftAndRelease)
        XCTAssertEqual(preferences.columnMode, .three)
        XCTAssertEqual(preferences.spacing, 15)
    }

    func testZeroSpacingMigratesToTwoPixelsWithoutOverwritingCustomSpacing() {
        defaults.set(2, forKey: "layoutDefaultsRevision")
        defaults.set(0, forKey: "spacing")

        var preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.spacing, 2)

        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(2, forKey: "layoutDefaultsRevision")
        defaults.set(7, forKey: "spacing")

        preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.spacing, 7)
    }

    func testUserCanChooseZeroAfterTwoPixelMigration() {
        defaults.set(3, forKey: "layoutDefaultsRevision")
        defaults.set(0, forKey: "spacing")

        let preferences = AppPreferences(defaults: defaults)

        XCTAssertEqual(preferences.spacing, 0)
    }
}

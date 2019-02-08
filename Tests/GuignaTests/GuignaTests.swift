import XCTest
@testable import Guigna

final class GuignaTests: XCTestCase {
    func testHomebrewList() {
		print(Homebrew.list)
    }

    static var allTests = [
        ("testHomebrewList", testHomebrewList),
    ]
}

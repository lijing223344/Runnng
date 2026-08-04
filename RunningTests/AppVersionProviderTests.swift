import XCTest
@testable import Running

final class AppVersionProviderTests: XCTestCase {
    func testDisplayStringIncludesShortVersionAndBuildWhenBothExist() {
        let bundle = MockBundle(
            info: [
                "CFBundleShortVersionString": "1.0.4",
                "CFBundleVersion": "4"
            ]
        )

        XCTAssertEqual(AppVersionProvider.displayString(bundle: bundle), "1.0.4 (4)")
    }

    func testDisplayStringFallsBackToShortVersion() {
        let bundle = MockBundle(
            info: [
                "CFBundleShortVersionString": "1.0.4"
            ]
        )

        XCTAssertEqual(AppVersionProvider.displayString(bundle: bundle), "1.0.4")
    }

    func testDisplayStringReturnsUnknownWhenVersionInfoMissing() {
        XCTAssertEqual(AppVersionProvider.displayString(bundle: MockBundle(info: [:])), "Unknown")
    }
}

private final class MockBundle: Bundle, @unchecked Sendable {
    private let info: [String: Any]

    init(info: [String: Any]) {
        self.info = info
        super.init()
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        info[key]
    }
}

import XCTest
@testable import BankTracking

final class MoneyTests: XCTestCase {
    /// French formatting uses narrow no-break spaces; compare on plain spaces to keep the tests readable.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func testFormatsCentsExactly() {
        XCTAssertEqual(plain(Money.format(123_456)), "1 234,56 €")
        XCTAssertEqual(plain(Money.format(5)), "0,05 €")
        XCTAssertEqual(plain(Money.format(0)), "0,00 €")
    }

    func testNegativeAmounts() {
        XCTAssertEqual(plain(Money.format(-4_290)), "-42,90 €")
    }

    func testSignedAddsPlusOnlyForIncome() {
        XCTAssertEqual(plain(Money.format(1_000, signed: true)), "+10,00 €")
        XCTAssertEqual(plain(Money.format(-1_000, signed: true)), "-10,00 €")
        XCTAssertEqual(plain(Money.format(0, signed: true)), "0,00 €")
    }

    func testLargeAmountsDoNotLosePrecision() {
        // 2^53 + 1 cents would already be wrong through Double.
        XCTAssertEqual(plain(Money.format(9_007_199_254_740_993)), "90 071 992 547 409,93 €")
    }

    func testPercent() {
        XCTAssertEqual(Money.percent(0.424), "42 %")
        XCTAssertEqual(Money.percent(-0.1), "-10 %")
    }
}

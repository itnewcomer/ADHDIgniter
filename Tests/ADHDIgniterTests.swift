import XCTest

final class ADHDIgniterTests: XCTestCase {
    func testRewardEngineBonus() {
        // ボーナスは0以上
        for _ in 0..<100 {
            let bonus = RewardEngine.calculateBonus()
            XCTAssertGreaterThanOrEqual(bonus, 0)
        }
    }

    func testRewardEnginePraise() {
        let praise = RewardEngine.randomPraise()
        XCTAssertFalse(praise.isEmpty)
    }
}

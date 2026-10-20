import Foundation
import GlassUI

func registerGlassFormatTests() {
    test("크레딧은 소수 1자리로 반올림한다") {
        expect(GlassFormat.credits(68.3939255104) == "68.4", "68.4 이어야 합니다")
        expect(GlassFormat.credits(3) == "3", "3 이어야 합니다")
        expect(GlassFormat.credits(nil) == "—", "nil 은 — 이어야 합니다")
    }

    test("크레딧은 소수 2자리를 지원한다") {
        expect(GlassFormat.credits(1.456, maximumFractionDigits: 2) == "1.46", "1.46 이어야 합니다")
    }

    test("퍼센트는 0~100 사이로 제한된다") {
        expect(GlassFormat.percentValue(0.246) == 25, "25 이어야 합니다")
        expect(GlassFormat.percentValue(-1) == 0, "음수는 0 이어야 합니다")
        expect(GlassFormat.percentValue(2) == 100, "100 을 넘으면 100 이어야 합니다")
        expect(GlassFormat.percent(0.5) == "50%", "50% 이어야 합니다")
    }

    test("토큰은 K/M 으로 줄여 쓴다") {
        expect(GlassFormat.tokens(999) == "999", "999 이하는 그대로")
        expect(GlassFormat.tokens(15_800) == "15.8K", "15.8K 이어야 합니다")
        expect(GlassFormat.tokens(180_900_000) == "180.9M", "180.9M 이어야 합니다")
    }

    test("카운트다운을 사람이 읽을 형태로 만든다") {
        let now = Date(timeIntervalSince1970: 1_000_000)
        expect(
            GlassFormat.countdown(to: now.addingTimeInterval(3 * 3600 + 20 * 60), now: now) == "3시간 20분 후",
            "3시간 20분 후 이어야 합니다"
        )
        expect(
            GlassFormat.countdown(to: now.addingTimeInterval(26 * 3600), now: now) == "1일 2시간 후",
            "1일 2시간 후 이어야 합니다"
        )
        expect(GlassFormat.countdown(to: now.addingTimeInterval(-10), now: now) == "초기화됨", "지난 시각은 초기화됨")
        expect(GlassFormat.countdown(to: nil, now: now) == "—", "nil 은 — 이어야 합니다")
    }
}

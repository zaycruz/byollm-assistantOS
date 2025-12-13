import Foundation
import Testing
@testable import byollm_assistantOS

struct VoiceNoteTitleBuilderTests {
    @Test func formatsTitleAsMonthDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        
        let tz = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_US_POSIX")
        
        // 2025-12-13T12:00:00Z
        let date = Date(timeIntervalSince1970: 1_765_645_200)
        let title = VoiceNoteTitleBuilder.title(for: date, calendar: cal, locale: locale, timeZone: tz)
        
        #expect(title == "Voice Note — Dec 13")
    }
}


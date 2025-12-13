import Foundation

struct VoiceNoteTitleBuilder {
    static func title(
        for date: Date,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d"
        
        return "Voice Note — \(formatter.string(from: date))"
    }
}


import Foundation
import Testing
@testable import byollm_assistantOS

struct TaskBucketingTests {
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func fixedNow() -> Date {
        // 2025-12-13T12:00:00Z
        Date(timeIntervalSince1970: 1_765_645_200)
    }
    
    @Test func inboxIncludesFutureDatedTasks() {
        let now = fixedNow()
        let cal = utcCalendar()
        let future = cal.date(byAdding: .day, value: 3, to: now)!
        
        let t = TaskItem(title: "Future", dueDate: future, createdAt: now, updatedAt: now)
        let filtered = TaskBucketing.filteredTasks(tasks: [t], filter: .inbox, now: now, calendar: cal)
        
        #expect(filtered.contains(t))
    }
    
    @Test func bucketsOverdueTasks() {
        let now = fixedNow()
        let cal = utcCalendar()
        let b = TaskBucketing.boundaries(now: now, calendar: cal)
        let yesterday = cal.date(byAdding: .day, value: -1, to: b.startOfToday)!
        
        let t = TaskItem(title: "Overdue", dueDate: yesterday, createdAt: now, updatedAt: now)
        #expect(TaskBucketing.bucket(for: t, now: now, calendar: cal) == .overdue)
    }
    
    @Test func sortsByNearestDueDateFirstWithinBucket() {
        let now = fixedNow()
        let cal = utcCalendar()
        
        let dueSoon = cal.date(byAdding: .day, value: 1, to: now)!
        let dueLater = cal.date(byAdding: .day, value: 3, to: now)!
        
        let t1 = TaskItem(title: "Later", dueDate: dueLater, createdAt: now, updatedAt: now)
        let t2 = TaskItem(title: "Soon", dueDate: dueSoon, createdAt: now, updatedAt: now)
        
        let sections = TaskBucketing.sections(for: [t1, t2], now: now, calendar: cal)
        let next7 = sections.first(where: { $0.bucket == .next7Days })?.tasks ?? []
        
        #expect(next7.map(\.title) == ["Soon", "Later"])
    }
    
    @Test func noDateBucketSortedByUpdatedAtDescending() {
        let now = fixedNow()
        let cal = utcCalendar()
        
        let older = cal.date(byAdding: .hour, value: -2, to: now)!
        let newer = cal.date(byAdding: .minute, value: -5, to: now)!
        
        let t1 = TaskItem(title: "Older", dueDate: nil, createdAt: now, updatedAt: older)
        let t2 = TaskItem(title: "Newer", dueDate: nil, createdAt: now, updatedAt: newer)
        
        let sections = TaskBucketing.sections(for: [t1, t2], now: now, calendar: cal)
        let noDate = sections.first(where: { $0.bucket == .noDate })?.tasks ?? []
        
        #expect(noDate.map(\.title) == ["Newer", "Older"])
    }
}


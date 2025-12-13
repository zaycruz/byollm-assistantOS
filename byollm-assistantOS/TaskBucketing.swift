import Foundation

enum TaskListFilter: String, CaseIterable, Identifiable {
    case inbox = "Inbox"
    case today = "Today"
    case upcoming = "Upcoming"
    case done = "Done"
    
    var id: String { rawValue }
}

enum TaskBucket: String, CaseIterable, Identifiable {
    case overdue = "Overdue"
    case today = "Today"
    case next7Days = "Next 7 Days"
    case later = "Later"
    case noDate = "No Date"
    
    var id: String { rawValue }
    
    static var displayOrder: [TaskBucket] {
        [.overdue, .today, .next7Days, .later, .noDate]
    }
}

struct TaskBucketing {
    struct Boundaries: Equatable {
        let startOfToday: Date
        let startOfTomorrow: Date
        let startOfDayAfter7: Date
    }
    
    static func boundaries(now: Date, calendar: Calendar) -> Boundaries {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let startOfDayAfter7 = calendar.date(byAdding: .day, value: 8, to: startOfToday) ?? startOfTomorrow
        return Boundaries(
            startOfToday: startOfToday,
            startOfTomorrow: startOfTomorrow,
            startOfDayAfter7: startOfDayAfter7
        )
    }
    
    static func filteredTasks(
        tasks: [TaskItem],
        filter: TaskListFilter,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let b = boundaries(now: now, calendar: calendar)
        
        return tasks.filter { task in
            switch filter {
            case .inbox:
                return !task.isDone
            case .today:
                guard let due = task.dueDate else { return false }
                return !task.isDone && due >= b.startOfToday && due < b.startOfTomorrow
            case .upcoming:
                guard let due = task.dueDate else { return false }
                return !task.isDone && due >= b.startOfTomorrow
            case .done:
                return task.isDone
            }
        }
    }
    
    static func bucket(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> TaskBucket {
        guard let due = task.dueDate else { return .noDate }
        
        let b = boundaries(now: now, calendar: calendar)
        if due < b.startOfToday { return .overdue }
        if due < b.startOfTomorrow { return .today }
        if due < b.startOfDayAfter7 { return .next7Days }
        return .later
    }
    
    static func sortForList(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            if let ld = lhs.dueDate, let rd = rhs.dueDate, ld != rd { return ld < rd }
            if lhs.dueDate != nil, rhs.dueDate == nil { return true }
            if lhs.dueDate == nil, rhs.dueDate != nil { return false }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
    
    static func sections(
        for tasks: [TaskItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(bucket: TaskBucket, tasks: [TaskItem])] {
        var grouped: [TaskBucket: [TaskItem]] = [:]
        for task in tasks {
            let bucket = bucket(for: task, now: now, calendar: calendar)
            grouped[bucket, default: []].append(task)
        }
        
        return TaskBucket.displayOrder.compactMap { bucket in
            guard let bucketTasks = grouped[bucket], !bucketTasks.isEmpty else { return nil }
            return (bucket: bucket, tasks: sortForList(bucketTasks))
        }
    }
}


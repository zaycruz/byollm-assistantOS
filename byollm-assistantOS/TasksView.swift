//
//  TasksView.swift
//  byollm-assistantOS
//
//  Created by GPT-5.2 on 12/12/25.
//

import SwiftUI

// MARK: - Model

struct TaskItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var isDone: Bool
    var dueDate: Date?
    let createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Persistence

@MainActor
final class TasksStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    
    private let storageKey = "tasks.v1"
    
    init() {
        load()
    }
    
    func create() -> TaskItem {
        let item = TaskItem()
        tasks.insert(item, at: 0)
        save()
        return item
    }
    
    func upsert(_ task: TaskItem) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.insert(task, at: 0)
        }
        sort()
        save()
    }
    
    func toggleDone(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDone.toggle()
        tasks[index].updatedAt = Date()
        sort()
        save()
    }
    
    func delete(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }
        save()
    }
    
    private func sort() {
        tasks.sort { lhs, rhs in
            switch (lhs.isDone, rhs.isDone) {
            case (false, true): return true
            case (true, false): return false
            default:
                // unfinished: nearest due date first, then updatedAt
                if let ld = lhs.dueDate, let rd = rhs.dueDate, ld != rd { return ld < rd }
                if lhs.dueDate != nil, rhs.dueDate == nil { return true }
                if lhs.dueDate == nil, rhs.dueDate != nil { return false }
                return lhs.updatedAt > rhs.updatedAt
            }
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            tasks = try JSONDecoder().decode([TaskItem].self, from: data)
            sort()
        } catch {
            tasks = []
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(tasks)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }
}

// MARK: - Tasks View

struct TasksView: View {
    @StateObject private var store = TasksStore()
    @State private var selectedFilter: TaskListFilter = .inbox
    @State private var editorTask: TaskItem?
    
    private var now: Date { Date() }
    private var calendar: Calendar { .current }
    
    private var inboxSections: [(bucket: TaskBucket, tasks: [TaskItem])] {
        let open = TaskBucketing.filteredTasks(tasks: store.tasks, filter: .inbox, now: now, calendar: calendar)
        return TaskBucketing.sections(for: open, now: now, calendar: calendar)
    }
    
    private var todayTasks: [TaskItem] {
        TaskBucketing.sortForList(
            TaskBucketing.filteredTasks(tasks: store.tasks, filter: .today, now: now, calendar: calendar)
        )
    }
    
    private var upcomingSections: [(bucket: TaskBucket, tasks: [TaskItem])] {
        let upcoming = TaskBucketing.filteredTasks(tasks: store.tasks, filter: .upcoming, now: now, calendar: calendar)
        return TaskBucketing.sections(for: upcoming, now: now, calendar: calendar)
            .filter { $0.bucket == .next7Days || $0.bucket == .later }
    }
    
    private var doneTasks: [TaskItem] {
        TaskBucketing.sortForList(
            TaskBucketing.filteredTasks(tasks: store.tasks, filter: .done, now: now, calendar: calendar)
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if isEmpty {
                        emptyState
                    } else {
                        tasksList
                    }
                }
            }
            .sheet(item: $editorTask) { task in
                TaskEditorView(
                    task: task,
                    onSave: { updated in
                        store.upsert(updated)
                        editorTask = nil
                    },
                    onDelete: {
                        store.delete(task)
                        editorTask = nil
                    }
                )
            }
        }
    }
    
    private var isEmpty: Bool {
        switch selectedFilter {
        case .inbox:
            return inboxSections.isEmpty
        case .today:
            return todayTasks.isEmpty
        case .upcoming:
            return upcomingSections.isEmpty
        case .done:
            return doneTasks.isEmpty
        }
    }
    
    @ViewBuilder
    private var tasksList: some View {
        switch selectedFilter {
        case .inbox:
            List {
                ForEach(inboxSections, id: \.bucket) { section in
                    Section(section.bucket.rawValue) {
                        ForEach(section.tasks) { task in
                            TaskRow(
                                task: task,
                                onToggleDone: { store.toggleDone(task) }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { editorTask = task }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DesignSystem.Colors.separator)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .today:
            List {
                Section(TaskBucket.today.rawValue) {
                    ForEach(todayTasks) { task in
                        TaskRow(
                            task: task,
                            onToggleDone: { store.toggleDone(task) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { editorTask = task }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(DesignSystem.Colors.separator)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .upcoming:
            List {
                ForEach(upcomingSections, id: \.bucket) { section in
                    Section(section.bucket.rawValue) {
                        ForEach(section.tasks) { task in
                            TaskRow(
                                task: task,
                                onToggleDone: { store.toggleDone(task) }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { editorTask = task }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DesignSystem.Colors.separator)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        case .done:
            List {
                ForEach(doneTasks) { task in
                    TaskRow(
                        task: task,
                        onToggleDone: { store.toggleDone(task) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { editorTask = task }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(DesignSystem.Colors.separator)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    editorTask = store.create()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(width: 44, height: 44)
                        .background(DesignSystem.Colors.surfaceElevated)
                        .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                .stroke(DesignSystem.Colors.border.opacity(0.7), lineWidth: DesignSystem.Layout.borderWidth)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New task")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Picker("", selection: $selectedFilter) {
                ForEach(TaskListFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(DesignSystem.Colors.chrome.opacity(0.98))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(DesignSystem.Colors.separator),
            alignment: .bottom
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            
            Image(systemName: "checklist")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            
            Text("No tasks")
                .font(DesignSystem.Typography.header())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text("Add a task to get started.")
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            Button("New Task", systemImage: "plus") {
                editorTask = store.create()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, 6)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

// MARK: - Row

private struct TaskRow: View {
    let task: TaskItem
    let onToggleDone: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleDone) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(task.isDone ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : task.title)
                    .font(DesignSystem.Typography.body().weight(.semibold))
                    .foregroundStyle(task.isDone ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                    .strikethrough(task.isDone, color: DesignSystem.Colors.textTertiary)
                    .lineLimit(1)
                
                if let due = task.dueDate {
                    Label {
                        Text(due, format: .dateTime.month(.abbreviated).day())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Editor

private struct TaskEditorView: View {
    @State private var draft: TaskItem
    let onSave: (TaskItem) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    init(task: TaskItem, onSave: @escaping (TaskItem) -> Void, onDelete: @escaping () -> Void) {
        _draft = State(initialValue: task)
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 12) {
                    TextField("Task", text: $draft.title)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.title())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    Divider()
                        .background(DesignSystem.Colors.separator)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Completed", isOn: $draft.isDone)
                            .tint(DesignSystem.Colors.accent)
                        
                        DatePicker(
                            "Due date",
                            selection: Binding(
                                get: { draft.dueDate ?? Date() },
                                set: { draft.dueDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                        .environment(\.locale, .current)
                        
                        Button {
                            draft.dueDate = nil
                        } label: {
                            Label("Clear due date", systemImage: "xmark.circle")
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                        
                        TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(DesignSystem.Colors.surface2)
                            .clipShape(.rect(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .background(DesignSystem.Colors.surface1)
                .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                        .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
                )
                .padding(16)
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(DesignSystem.Colors.accent)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    private func save() {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !(trimmedTitle.isEmpty && trimmedNotes.isEmpty) else {
            onDelete()
            return
        }
        
        draft.updatedAt = Date()
        onSave(draft)
    }
}

#Preview {
    TasksView()
}



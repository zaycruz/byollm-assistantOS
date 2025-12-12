//
//  NotesView.swift
//  byollm-assistantOS
//
//  Created by GPT-5.2 on 12/12/25.
//

import SwiftUI

// MARK: - Model

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), title: String = "", body: String = "", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        
        let firstLine = body
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        return firstLine.isEmpty ? "Untitled" : firstLine
    }
    
    var preview: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Persistence

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    
    private let storageKey = "notes.v1"
    
    init() {
        load()
    }
    
    func create() -> Note {
        let note = Note()
        notes.insert(note, at: 0)
        save()
        return note
    }
    
    func upsert(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
        } else {
            notes.insert(note, at: 0)
        }
        sort()
        save()
    }
    
    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }
    
    func delete(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        save()
    }
    
    private func sort() {
        notes.sort { $0.updatedAt > $1.updatedAt }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            notes = try JSONDecoder().decode([Note].self, from: data)
            sort()
        } catch {
            notes = []
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(notes)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }
}

// MARK: - Notes View

struct NotesView: View {
    @StateObject private var store = NotesStore()
    @State private var query: String = ""
    @State private var editorNote: Note?
    
    private var filteredNotes: [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.notes }
        return store.notes.filter { note in
            note.displayTitle.localizedCaseInsensitiveContains(q) ||
            note.preview.localizedCaseInsensitiveContains(q)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    header
                    
                    if filteredNotes.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filteredNotes) { note in
                                Button {
                                    editorNote = note
                                } label: {
                                    NoteRow(note: note)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparatorTint(DesignSystem.Colors.separator)
                            }
                            .onDelete(perform: deleteNotes)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .sheet(item: $editorNote) { note in
                NoteEditorView(
                    note: note,
                    onSave: { updated in
                        store.upsert(updated)
                        editorNote = nil
                    },
                    onDelete: {
                        store.delete(note)
                        editorNote = nil
                    }
                )
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Notes")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    editorNote = store.create()
                } label: {
                    Image(systemName: "square.and.pencil")
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
                .accessibilityLabel("New note")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                TextField("Search notes…", text: $query)
                    .textFieldStyle(.plain)
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DesignSystem.Colors.surfaceElevated)
            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.border.opacity(0.75), lineWidth: DesignSystem.Layout.borderWidth)
            )
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
            
            Image(systemName: query.isEmpty ? "note.text" : "magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            
            Text(query.isEmpty ? "No notes yet" : "No results")
                .font(DesignSystem.Typography.header())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Text(query.isEmpty ? "Create your first note." : "Try a different search.")
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            if query.isEmpty {
                Button("New Note", systemImage: "square.and.pencil") {
                    editorNote = store.create()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 6)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        // If search is active, map offsets back into the underlying list.
        let current = filteredNotes
        let ids = offsets.map { current[$0].id }
        for id in ids {
            if let note = store.notes.first(where: { $0.id == id }) {
                store.delete(note)
            }
        }
    }
}

// MARK: - Row

private struct NoteRow: View {
    let note: Note
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.accentSoft)
                .clipShape(.rect(cornerRadius: 8, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(note.displayTitle)
                    .font(DesignSystem.Typography.body().weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(note.updatedAt, format: .dateTime.month(.abbreviated).day())
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textTertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Editor

private struct NoteEditorView: View {
    @State private var draft: Note
    let onSave: (Note) -> Void
    let onDelete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isBodyFocused: Bool
    
    init(note: Note, onSave: @escaping (Note) -> Void, onDelete: @escaping () -> Void) {
        _draft = State(initialValue: note)
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 12) {
                    TextField("Title", text: $draft.title)
                        .textFieldStyle(.plain)
                        .font(DesignSystem.Typography.title())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    
                    Divider()
                        .background(DesignSystem.Colors.separator)
                        .padding(.horizontal, 16)
                    
                    TextEditor(text: $draft.body)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($isBodyFocused)
                        .padding(.horizontal, 12)
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
            .navigationTitle("Note")
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
            .onAppear { isBodyFocused = draft.body.isEmpty }
        }
    }
    
    private func save() {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = draft.body.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If empty, delete instead of saving empty notes.
        guard !(trimmedTitle.isEmpty && trimmedBody.isEmpty) else {
            onDelete()
            return
        }
        
        draft.updatedAt = Date()
        onSave(draft)
    }
}

#Preview {
    NotesView()
}


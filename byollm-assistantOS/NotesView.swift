//
//  NotesView.swift
//  byollm-assistantOS
//
//  Created by master on 12/5/25.
//

import SwiftUI

// MARK: - Note Model
struct Note: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var audioFileName: String? // For voice notes
    
    init(id: UUID = UUID(), title: String = "", content: String = "", isPinned: Bool = false, audioFileName: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isPinned = isPinned
        self.audioFileName = audioFileName
    }
    
    var hasAudio: Bool {
        audioFileName != nil
    }
    
    // Computed property for the first line (used as title)
    var displayTitle: String {
        if hasAudio && content.isEmpty {
            return "Voice Note"
        }
        if !content.isEmpty {
            let lines = content.components(separatedBy: .newlines)
            let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) ?? "New Note"
            return firstLine.isEmpty ? "New Note" : firstLine
        }
        return "New Note"
    }
    
    // Computed property for preview text (everything after first line)
    var displayPreview: String {
        if hasAudio && content.isEmpty {
            return "Audio recording"
        }
        if !content.isEmpty {
            let lines = content.components(separatedBy: .newlines)
            if lines.count > 1 {
                return lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return hasAudio ? "Audio recording" : ""
    }
}

// MARK: - Notes Manager
class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    
    private let notesKey = "savedNotes"
    
    init() {
        loadNotes()
    }
    
    var pinnedNotes: [Note] {
        notes.filter { $0.isPinned }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    var unpinnedNotes: [Note] {
        notes.filter { !$0.isPinned }.sorted { $0.modifiedAt > $1.modifiedAt }
    }
    
    func addNote(_ note: Note) {
        notes.insert(note, at: 0)
        saveNotes()
    }
    
    func updateNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = note
            updatedNote.modifiedAt = Date()
            notes[index] = updatedNote
            saveNotes()
        }
    }
    
    func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isPinned.toggle()
            saveNotes()
        }
    }
    
    func deleteNote(_ note: Note) {
        // Delete audio file if exists
        if let audioFileName = note.audioFileName {
            deleteAudioFile(fileName: audioFileName)
        }
        notes.removeAll { $0.id == note.id }
        saveNotes()
    }
    
    func deleteNotes(at offsets: IndexSet) {
        // Delete audio files for notes being deleted
        offsets.forEach { index in
            if let audioFileName = notes[index].audioFileName {
                deleteAudioFile(fileName: audioFileName)
            }
        }
        notes.remove(atOffsets: offsets)
        saveNotes()
    }
    
    private func deleteAudioFile(fileName: String) {
        let audioURL = getDocumentsDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: audioURL)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: notesKey)
        }
    }
    
    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }
}

// MARK: - Notes List View
struct NotesView: View {
    @StateObject private var notesManager = NotesManager()
    @State private var selectedNote: Note?
    @State private var searchText = ""
    @State private var showingNoteEditor = false
    @Environment(\.dismiss) var dismiss
    
    // Side panel mode
    var isInSidePanel: Bool = false
    var onBack: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    private var filteredPinnedNotes: [Note] {
        let pinned = notesManager.pinnedNotes
        if searchText.isEmpty {
            return pinned
        }
        return pinned.filter { note in
            note.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredUnpinnedNotes: [Note] {
        let unpinned = notesManager.unpinnedNotes
        if searchText.isEmpty {
            return unpinned
        }
        return unpinned.filter { note in
            note.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if isInSidePanel {
                        Button(action: { onBack?() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Notes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !isInSidePanel {
                        Button(action: { dismiss() }) {
                            Text("Done")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: { onDismiss?() }) {
                            Text("Done")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search", text: $searchText)
                        .foregroundColor(.primary)
                }
                .padding(8)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Notes Count
                if !notesManager.notes.isEmpty {
                    HStack {
                        Text("\(filteredPinnedNotes.count + filteredUnpinnedNotes.count) Note\(filteredPinnedNotes.count + filteredUnpinnedNotes.count == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                
                // Notes List
                if filteredPinnedNotes.isEmpty && filteredUnpinnedNotes.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(searchText.isEmpty ? "No Notes" : "No Results")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("Create a note to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        Spacer()
                    }
                } else {
                    List {
                        // Pinned Notes Section
                        if !filteredPinnedNotes.isEmpty {
                            Section(header: Text("Pinned").textCase(.uppercase)) {
                                ForEach(filteredPinnedNotes) { note in
                                    NoteRow(note: note)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedNote = note
                                            showingNoteEditor = true
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                notesManager.togglePin(note)
                                            } label: {
                                                Label("Unpin", systemImage: "pin.slash")
                                            }
                                            .tint(.orange)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                notesManager.deleteNote(note)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        
                        // Regular Notes Section
                        if !filteredUnpinnedNotes.isEmpty {
                            Section(header: filteredPinnedNotes.isEmpty ? AnyView(EmptyView()) : AnyView(Text("Notes").textCase(.uppercase))) {
                                ForEach(filteredUnpinnedNotes) { note in
                                    NoteRow(note: note)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedNote = note
                                            showingNoteEditor = true
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                notesManager.togglePin(note)
                                            } label: {
                                                Label("Pin", systemImage: "pin")
                                            }
                                            .tint(.yellow)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                notesManager.deleteNote(note)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color(UIColor.systemGroupedBackground))
                }
            }
            
            // Floating Action Button (Apple Notes style)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        selectedNote = nil
                        showingNoteEditor = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(
                notesManager: notesManager,
                note: selectedNote
            )
        }
    }
}

// MARK: - Note Row
struct NoteRow: View {
    let note: Note
    
    private var timeAgoText: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: note.modifiedAt, to: now)
        
        if let year = components.year, year > 0 {
            return "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return "\(month)mo ago"
        } else if let day = components.day, day > 0 {
            return "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if note.hasAudio {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                Text(note.displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if !note.displayPreview.isEmpty {
                Text(note.displayPreview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(timeAgoText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !note.displayPreview.isEmpty || note.hasAudio {
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if note.hasAudio && !note.content.isEmpty {
                        Text("Voice note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !note.content.isEmpty {
                        let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                        Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Audio Recorder
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioFileName: String?
    
    func startRecording() -> String? {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let fileName = UUID().uuidString + ".m4a"
            let audioURL = getDocumentsDirectory().appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            audioFileName = fileName
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingTime = self?.audioRecorder?.currentTime ?? 0
            }
            
            return fileName
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    func stopRecording() -> String? {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        return audioFileName
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Audio Player
class AudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    func playAudio(fileName: String) {
        let audioURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            isPlaying = true
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.currentTime = self?.audioPlayer?.currentTime ?? 0
                if self?.audioPlayer?.isPlaying == false {
                    self?.stopAudio()
                }
            }
        } catch {
            print("Failed to play audio: \(error.localizedDescription)")
        }
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        timer?.invalidate()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - Note Editor View
struct NoteEditorView: View {
    @ObservedObject var notesManager: NotesManager
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var content: String
    @State private var audioFileName: String?
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingAudioPermissionAlert = false
    @Environment(\.dismiss) var dismiss
    @FocusState private var isFocused: Bool
    
    private let note: Note?
    private let isNewNote: Bool
    
    init(notesManager: NotesManager, note: Note?) {
        self.notesManager = notesManager
        self.note = note
        self.isNewNote = note == nil
        
        _content = State(initialValue: note?.content ?? "")
        _audioFileName = State(initialValue: note?.audioFileName)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Audio Recording/Playback Section
                    if audioRecorder.isRecording {
                        // Recording UI
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                    .opacity(0.8)
                                
                                Text("Recording")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                            
                            Text(formatTime(audioRecorder.recordingTime))
                                .font(.system(size: 36, weight: .light, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 40) {
                                Button(action: {
                                    if let fileName = audioRecorder.stopRecording() {
                                        audioFileName = fileName
                                    }
                                }) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                        .frame(width: 60, height: 60)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                    } else if let fileName = audioFileName {
                        // Audio Player UI
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "waveform")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                
                                Text("Voice Note")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    if audioPlayer.isPlaying {
                                        audioPlayer.pauseAudio()
                                    } else {
                                        audioPlayer.playAudio(fileName: fileName)
                                    }
                                }) {
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if audioPlayer.duration > 0 {
                                        ProgressView(value: audioPlayer.currentTime, total: audioPlayer.duration)
                                            .tint(.blue)
                                        
                                        HStack {
                                            Text(formatTime(audioPlayer.currentTime))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(formatTime(audioPlayer.duration))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("Tap to play")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button(action: {
                                    audioFileName = nil
                                    audioPlayer.stopAudio()
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.red)
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                    
                    // Text Editor
                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.systemBackground))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        saveAndDismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                                .fontWeight(.semibold)
                            Text("Notes")
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Voice recording button
                        if !audioRecorder.isRecording && audioFileName == nil {
                            Button(action: {
                                requestMicrophonePermission()
                            }) {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Menu {
                            if !isNewNote {
                                Button(action: {
                                    if let note = note {
                                        notesManager.togglePin(note)
                                        saveAndDismiss()
                                    }
                                }) {
                                    Label(note?.isPinned == true ? "Unpin" : "Pin", 
                                          systemImage: note?.isPinned == true ? "pin.slash" : "pin")
                                }
                            }
                            
                            Button(action: {
                                showingShareSheet = true
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            
                            if !isNewNote {
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    showingDeleteAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let note = note {
                    notesManager.deleteNote(note)
                }
                audioPlayer.stopAudio()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this note?")
        }
        .alert("Microphone Access", isPresented: $showingAudioPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Please allow microphone access in Settings to record voice notes.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if #available(iOS 16.0, *) {
                ShareSheet(items: [content])
            }
        }
        .onAppear {
            if isNewNote {
                isFocused = true
            }
        }
        .onDisappear {
            audioPlayer.stopAudio()
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    _ = audioRecorder.startRecording()
                } else {
                    showingAudioPermissionAlert = true
                }
            }
        }
    }
    
    private func saveAndDismiss() {
        audioPlayer.stopAudio()
        saveNote()
        dismiss()
    }
    
    private func saveNote() {
        // Don't save completely empty notes
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If note is completely empty (no content and no audio), don't save or delete if existing
        if trimmedContent.isEmpty && audioFileName == nil {
            if let note = note {
                notesManager.deleteNote(note)
            }
            return
        }
        
        if let existingNote = note {
            // Update existing note
            var updatedNote = existingNote
            updatedNote.content = content
            updatedNote.audioFileName = audioFileName
            notesManager.updateNote(updatedNote)
        } else {
            // Create new note
            let newNote = Note(content: content, audioFileName: audioFileName)
            notesManager.addNote(newNote)
        }
    }
}

// MARK: - Share Sheet
@available(iOS 16.0, *)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NotesView()
}

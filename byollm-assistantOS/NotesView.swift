//
//  NotesView.swift
//  byollm-assistantOS
//
//  Created by master on 12/5/25.
//

import SwiftUI
import AVFoundation

// MARK: - Note Model
struct Note: Identifiable, Codable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var audioFileName: String? // For voice notes
    
    // Optional metadata for LLM context
    var sponsoringThought: String? // The main idea or reason behind creating this note
    var creationContext: String? // The surrounding context behind its creation
    
    init(id: UUID = UUID(), title: String = "", content: String = "", isPinned: Bool = false, audioFileName: String? = nil, sponsoringThought: String? = nil, creationContext: String? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isPinned = isPinned
        self.audioFileName = audioFileName
        self.sponsoringThought = sponsoringThought
        self.creationContext = creationContext
    }
    
    var hasAudio: Bool {
        audioFileName != nil
    }
    
    var hasMetadata: Bool {
        let hasSponsoringThought = !(sponsoringThought?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasContext = !(creationContext?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasSponsoringThought || hasContext
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
    @State private var isSearchFocused = false
    @Environment(\.dismiss) var dismiss
    @Namespace private var animation
    
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
            note.content.localizedCaseInsensitiveContains(searchText) ||
            (note.sponsoringThought?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (note.creationContext?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var filteredUnpinnedNotes: [Note] {
        let unpinned = notesManager.unpinnedNotes
        if searchText.isEmpty {
            return unpinned
        }
        return unpinned.filter { note in
            note.displayTitle.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText) ||
            (note.sponsoringThought?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (note.creationContext?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.systemBackground).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Enhanced Header
                ZStack {
                    // Glassmorphism effect
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    HStack(spacing: 16) {
                        if isInSidePanel {
                            Button(action: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onBack?()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chevron.left")
                                        .font(.body.weight(.semibold))
                                    Text("Back")
                                        .font(.body)
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("Notes")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .primary.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            if !notesManager.notes.isEmpty {
                                Text("\(filteredPinnedNotes.count + filteredUnpinnedNotes.count) note\(filteredPinnedNotes.count + filteredUnpinnedNotes.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if isInSidePanel {
                                    onDismiss?()
                                } else {
                                    dismiss()
                                }
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(height: 80)
                
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("Search notes...", text: $searchText)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                searchText = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Notes List
                if filteredPinnedNotes.isEmpty && filteredUnpinnedNotes.isEmpty {
                    EmptyNotesView(searchText: searchText, onCreate: {
                        selectedNote = nil
                        showingNoteEditor = true
                    })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Pinned Notes Section
                            if !filteredPinnedNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "pin.fill")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                        Text("PINNED")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                    
                                    ForEach(filteredPinnedNotes) { note in
                                        PremiumNoteCard(note: note)
                                            .onTapGesture {
                                                selectedNote = note
                                                showingNoteEditor = true
                                            }
                                            .contextMenu {
                                                Button(action: { notesManager.togglePin(note) }) {
                                                    Label("Unpin", systemImage: "pin.slash")
                                                }
                                                Button(role: .destructive, action: { notesManager.deleteNote(note) }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .transition(.asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale.combined(with: .opacity)
                                            ))
                                    }
                                }
                                .padding(.bottom, 24)
                            }
                            
                            // Regular Notes Section
                            if !filteredUnpinnedNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    if !filteredPinnedNotes.isEmpty {
                                        Text("NOTES")
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 20)
                                            .padding(.top, 8)
                                    }
                                    
                                    ForEach(filteredUnpinnedNotes) { note in
                                        PremiumNoteCard(note: note)
                                            .onTapGesture {
                                                selectedNote = note
                                                showingNoteEditor = true
                                            }
                                            .contextMenu {
                                                Button(action: { notesManager.togglePin(note) }) {
                                                    Label("Pin", systemImage: "pin")
                                                }
                                                Button(role: .destructive, action: { notesManager.deleteNote(note) }) {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .transition(.asymmetric(
                                                insertion: .scale.combined(with: .opacity),
                                                removal: .scale.combined(with: .opacity)
                                            ))
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            
            // Premium Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            selectedNote = nil
                            showingNoteEditor = true
                        }
                    }) {
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.orange.opacity(0.6),
                                            Color.orange.opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 28,
                                        endRadius: 45
                                    )
                                )
                                .frame(width: 90, height: 90)
                            
                            // Main button
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.orange,
                                            Color.orange.opacity(0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .shadow(color: .orange.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 28)
                    .padding(.bottom, 28)
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: filteredPinnedNotes.count)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: filteredUnpinnedNotes.count)
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(
                notesManager: notesManager,
                note: selectedNote
            )
        }
    }
}

// MARK: - Premium Note Card
struct PremiumNoteCard: View {
    let note: Note
    @State private var isPressed = false
    
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Left accent bar
                if note.isPinned {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4, height: 60)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title row with icons
                    HStack(spacing: 8) {
                        if note.hasAudio {
                            ZStack {
                                Circle()
                                    .fill(.blue.opacity(0.1))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "waveform")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .blue.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        
                        Text(note.displayTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                                .rotationEffect(.degrees(45))
                        }
                    }
                    
                    // Preview text
                    if !note.displayPreview.isEmpty {
                        Text(note.displayPreview)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Metadata row
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .medium))
                            Text(timeAgoText)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.secondary.opacity(0.8))
                        
                        if !note.content.isEmpty || note.hasAudio || note.hasMetadata {
                            Circle()
                                .fill(.secondary.opacity(0.5))
                                .frame(width: 3, height: 3)
                            
                            if note.hasAudio && !note.content.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Voice")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue.opacity(0.8))
                            } else if !note.content.isEmpty {
                                let wordCount = note.content.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                                Text("\(wordCount) word\(wordCount == 1 ? "" : "s")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                            
                            if note.hasMetadata {
                                Circle()
                                    .fill(.secondary.opacity(0.5))
                                    .frame(width: 3, height: 3)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 10, weight: .medium))
                                    Text("Context")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.purple.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.leading, !note.isPinned ? 16 : 0)
                .padding(.vertical, 16)
                .padding(.trailing, 16)
            }
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(isPressed ? 0.1 : 0.05), radius: isPressed ? 5 : 10, x: 0, y: isPressed ? 2 : 5)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
            // Long press handled
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

// MARK: - Empty Notes View
struct EmptyNotesView: View {
    let searchText: String
    let onCreate: () -> Void
    @State private var animationAmount = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.2),
                                Color.orange.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(animationAmount)
                    .opacity(2 - animationAmount)
                
                Image(systemName: searchText.isEmpty ? "note.text" : "magnifyingglass")
                    .font(.system(size: 70, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .orange.opacity(0.7),
                                .orange.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text(searchText.isEmpty ? "No Notes Yet" : "No Results Found")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ? "Tap the + button to create your first note" : "Try adjusting your search")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            if searchText.isEmpty {
                Button(action: onCreate) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Create Note")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14, antialiased: true)
                    .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                }
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                animationAmount = 2.0
            }
        }
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
    @State private var sponsoringThought: String
    @State private var creationContext: String
    @State private var showingMetadata: Bool
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingAudioPermissionAlert = false
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: EditorField?
    
    private let note: Note?
    private let isNewNote: Bool
    
    enum EditorField {
        case content
        case sponsoringThought
        case creationContext
    }
    
    init(notesManager: NotesManager, note: Note?) {
        self.notesManager = notesManager
        self.note = note
        self.isNewNote = note == nil
        
        _content = State(initialValue: note?.content ?? "")
        _audioFileName = State(initialValue: note?.audioFileName)
        _sponsoringThought = State(initialValue: note?.sponsoringThought ?? "")
        _creationContext = State(initialValue: note?.creationContext ?? "")
        _showingMetadata = State(initialValue: note?.hasMetadata ?? false)
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
                    
                    // Metadata Section (Collapsible)
                    VStack(spacing: 0) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingMetadata.toggle()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.purple)
                                
                                Text("LLM Context")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                if !sponsoringThought.isEmpty || !creationContext.isEmpty {
                                    Circle()
                                        .fill(.purple)
                                        .frame(width: 6, height: 6)
                                }
                                
                                Spacer()
                                
                                Image(systemName: showingMetadata ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                        }
                        .buttonStyle(.plain)
                        
                        if showingMetadata {
                            VStack(spacing: 12) {
                                // Sponsoring Thought
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Sponsoring Thought")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("What prompted this note?", text: $sponsoringThought, axis: .vertical)
                                        .font(.system(size: 15))
                                        .lineLimit(2...4)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(UIColor.tertiarySystemBackground))
                                        )
                                        .focused($focusedField, equals: .sponsoringThought)
                                }
                                
                                // Creation Context
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Surrounding Context")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    TextField("What were you doing, thinking about, or working on?", text: $creationContext, axis: .vertical)
                                        .font(.system(size: 15))
                                        .lineLimit(2...4)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(UIColor.tertiarySystemBackground))
                                        )
                                        .focused($focusedField, equals: .creationContext)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Divider()
                    }
                    
                    // Text Editor
                    TextEditor(text: $content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .focused($focusedField, equals: .content)
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
                focusedField = .content
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
        
        // Prepare metadata (nil if empty)
        let trimmedSponsoringThought = sponsoringThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCreationContext = creationContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSponsoringThought: String? = trimmedSponsoringThought.isEmpty ? nil : trimmedSponsoringThought
        let finalCreationContext: String? = trimmedCreationContext.isEmpty ? nil : trimmedCreationContext
        
        if let existingNote = note {
            // Update existing note
            var updatedNote = existingNote
            updatedNote.content = content
            updatedNote.audioFileName = audioFileName
            updatedNote.sponsoringThought = finalSponsoringThought
            updatedNote.creationContext = finalCreationContext
            notesManager.updateNote(updatedNote)
        } else {
            // Create new note
            let newNote = Note(
                content: content,
                audioFileName: audioFileName,
                sponsoringThought: finalSponsoringThought,
                creationContext: finalCreationContext
            )
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

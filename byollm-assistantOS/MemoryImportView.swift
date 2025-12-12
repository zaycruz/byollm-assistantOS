//
//  MemoryImportView.swift
//  byollm-assistantOS
//
//  Import local data (notes, tasks, conversations, profile) from JSON.
//

import SwiftUI
import UniformTypeIdentifiers

struct MemoryImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var summary: ImportSummary?
    @State private var statusText: String?
    @State private var errorText: String?
    @State private var pendingPayload: ImportPayload?
    
    var body: some View {
        ZStack {
            NatureTechBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Import data from a JSON file. We'll merge it into what's already on this device.")
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        
                        VStack(spacing: 0) {
                            Button {
                                isPickerPresented = confirmPicker()
                            } label: {
                                SettingsRow(icon: "square.and.arrow.down", title: "Choose file", showChevron: true)
                            }
                            .buttonStyle(.plain)
                            
                            if let summary {
                                Divider().background(DesignSystem.Colors.separator).padding(.leading, 56)
                                
                                HStack(spacing: 16) {
                                    Image(systemName: "tray.full")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Ready to import")
                                            .font(DesignSystem.Typography.body().weight(.semibold))
                                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                                        
                                        Text(summary.humanDescription)
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(16)
                            }
                        }
                        .mattePanel()
                        .padding(.horizontal, 20)
                        
                        if let errorText {
                            Text(errorText)
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.error)
                                .padding(.horizontal, 20)
                        }
                        
                        if let statusText {
                            Text(statusText)
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.success)
                                .padding(.horizontal, 20)
                        }
                        
                        Button {
                            Task { await performImport() }
                        } label: {
                            HStack {
                                Spacer()
                                if isImporting {
                                    ProgressView()
                                        .tint(DesignSystem.Colors.onAccent)
                                } else {
                                    Text("Import")
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                        .disabled(isImporting || pendingPayload == nil)
                        
                        Spacer(minLength: 20)
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await loadFile(url: url) }
            case .failure(let error):
                errorText = "Couldn't open file: \(error.localizedDescription)"
                statusText = nil
            }
        }
        .navigationBarHidden(true)
    }
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            
            Text("Memory")
                .font(DesignSystem.Typography.body().weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(DesignSystem.Colors.chrome.opacity(0.98))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(DesignSystem.Colors.separator),
            alignment: .bottom
        )
    }
    
    private func confirmPicker() -> Bool {
        errorText = nil
        statusText = nil
        return true
    }
    
    private func loadFile(url: URL) async {
        await MainActor.run {
            isImporting = true
            errorText = nil
            statusText = nil
            summary = nil
            pendingPayload = nil
        }
        
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        
        do {
            let data = try Data(contentsOf: url)
            let payload = try decodePayload(from: data)
            await MainActor.run {
                pendingPayload = payload
                summary = ImportSummary(from: payload)
                isImporting = false
            }
        } catch {
            await MainActor.run {
                errorText = "Couldn't read import file: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }
    
    private func performImport() async {
        guard let payload = pendingPayload else { return }
        await MainActor.run {
            isImporting = true
            errorText = nil
            statusText = nil
        }
        
        do {
            try apply(payload: payload)
            await MainActor.run {
                isImporting = false
                statusText = "Imported: \(ImportSummary(from: payload).humanDescription)"
            }
        } catch {
            await MainActor.run {
                isImporting = false
                errorText = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Import model

private struct UserProfileImport: Codable {
    var name: String?
    var occupation: String?
    var about: String?
}

private struct ImportPayload {
    var notes: [Note] = []
    var tasks: [TaskItem] = []
    var conversations: [Conversation] = []
    var profile: UserProfileImport?
}

private struct ImportSummary {
    let notesCount: Int
    let tasksCount: Int
    let conversationsCount: Int
    let hasProfile: Bool
    
    init(from payload: ImportPayload) {
        notesCount = payload.notes.count
        tasksCount = payload.tasks.count
        conversationsCount = payload.conversations.count
        hasProfile = payload.profile != nil
    }
    
    var humanDescription: String {
        var parts: [String] = []
        if notesCount > 0 { parts.append("\(notesCount) notes") }
        if tasksCount > 0 { parts.append("\(tasksCount) tasks") }
        if conversationsCount > 0 { parts.append("\(conversationsCount) chats") }
        if hasProfile { parts.append("profile") }
        return parts.isEmpty ? "Nothing recognized" : parts.joined(separator: " • ")
    }
}

private func decodePayload(from data: Data) throws -> ImportPayload {
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    
    let isoDecoder = JSONDecoder()
    isoDecoder.dateDecodingStrategy = .iso8601
    let defaultDecoder = JSONDecoder()
    
    // If the file is a raw array, treat it as conversation history.
    if let array = object as? [Any] {
        // Try conversations first (iso), then fallback (default).
        if let conversations: [Conversation] = try decodeSection(array, decoder: isoDecoder) ?? decodeSection(array, decoder: defaultDecoder) {
            return ImportPayload(notes: [], tasks: [], conversations: conversations, profile: nil)
        }
    }
    
    guard let dict = object as? [String: Any] else {
        return ImportPayload()
    }
    
    var payload = ImportPayload()
    
    if let notesAny = dict["notes"] {
        payload.notes = (try decodeSection(notesAny, decoder: defaultDecoder) ?? decodeSection(notesAny, decoder: isoDecoder)) ?? []
    }
    if let tasksAny = dict["tasks"] {
        payload.tasks = (try decodeSection(tasksAny, decoder: defaultDecoder) ?? decodeSection(tasksAny, decoder: isoDecoder)) ?? []
    }
    if let convAny = dict["conversations"] ?? dict["conversationHistory"] {
        payload.conversations = (try decodeSection(convAny, decoder: isoDecoder) ?? decodeSection(convAny, decoder: defaultDecoder)) ?? []
    }
    if let profileAny = dict["profile"] ?? dict["userProfile"] {
        payload.profile = (try decodeSection(profileAny, decoder: defaultDecoder) ?? decodeSection(profileAny, decoder: isoDecoder))
    }
    
    return payload
}

private func decodeSection<T: Decodable>(_ any: Any, decoder: JSONDecoder) throws -> T? {
    do {
        let sectionData = try JSONSerialization.data(withJSONObject: any, options: [])
        return try decoder.decode(T.self, from: sectionData)
    } catch {
        return nil
    }
}

private func apply(payload: ImportPayload) throws {
    // Notes (stored as "notes.v1" using default JSONEncoder/Decoder)
    if !payload.notes.isEmpty {
        let key = "notes.v1"
        let existing: [Note] = (try? loadArray(key: key, dateStrategy: nil)) ?? []
        let merged = mergeById(existing, payload.notes) { $0.updatedAt }
        try saveArray(key: key, merged, dateStrategy: nil)
    }
    
    // Tasks (stored as "tasks.v1" using default JSONEncoder/Decoder)
    if !payload.tasks.isEmpty {
        let key = "tasks.v1"
        let existing: [TaskItem] = (try? loadArray(key: key, dateStrategy: nil)) ?? []
        let merged = mergeById(existing, payload.tasks) { $0.updatedAt }
        try saveArray(key: key, merged, dateStrategy: nil)
    }
    
    // Conversations (stored as "conversationHistory" using ISO8601 dates)
    if !payload.conversations.isEmpty {
        let key = "conversationHistory"
        let existing: [Conversation] = (try? loadArray(key: key, dateStrategy: .iso8601)) ?? []
        // createdAt is immutable; prefer the newer one by createdAt if duplicate ids exist.
        let merged = mergeById(existing, payload.conversations) { $0.createdAt }
        try saveArray(key: key, merged, dateStrategy: .iso8601)
    }
    
    // Profile
    if let profile = payload.profile {
        if let name = profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            UserDefaults.standard.set(name, forKey: "userProfile.name")
        }
        if let occupation = profile.occupation?.trimmingCharacters(in: .whitespacesAndNewlines), !occupation.isEmpty {
            UserDefaults.standard.set(occupation, forKey: "userProfile.occupation")
        }
        if let about = profile.about?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
            UserDefaults.standard.set(about, forKey: "userProfile.about")
        }
    }
}

private func mergeById<T: Identifiable>(
    _ existing: [T],
    _ incoming: [T],
    sortKey: (T) -> Date
) -> [T] where T.ID == UUID {
    var map: [UUID: T] = [:]
    for item in existing { map[item.id] = item }
    for item in incoming { map[item.id] = item }
    return map.values.sorted { sortKey($0) > sortKey($1) }
}

private enum DateCodingStrategy {
    case iso8601
}

private func loadArray<T: Decodable>(key: String, dateStrategy: DateCodingStrategy?) throws -> [T] {
    guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
    let decoder = JSONDecoder()
    if dateStrategy == .iso8601 {
        decoder.dateDecodingStrategy = .iso8601
    }
    return try decoder.decode([T].self, from: data)
}

private func saveArray<T: Encodable>(key: String, _ array: [T], dateStrategy: DateCodingStrategy?) throws {
    let encoder = JSONEncoder()
    if dateStrategy == .iso8601 {
        encoder.dateEncodingStrategy = .iso8601
    }
    let data = try encoder.encode(array)
    UserDefaults.standard.set(data, forKey: key)
}



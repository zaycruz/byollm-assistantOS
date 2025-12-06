//
//  ContextImportView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct ContextImportView: View {
    @ObservedObject var manager: ARISEManager
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedType: ContextType = .manual
    @State private var showingSourceList = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        importSection
                        
                        if !manager.contextSources.isEmpty {
                            existingSourcesSection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Add Context")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveContext()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Context")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Add notes, conversations, or documents to help the AI generate better skill trees.")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Type")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(spacing: 12) {
                    ForEach([ContextType.manual, .note, .conversation, .document], id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            VStack(spacing: 6) {
                                Image(systemName: typeIcon(type))
                                    .font(.title3)
                                Text(typeName(type))
                                    .font(.caption)
                            }
                            .foregroundColor(selectedType == type ? .white : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedType == type ? Color.purple : Color.white.opacity(0.05))
                            )
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Title (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextField("e.g., Project Requirements, Meeting Notes", text: $title)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Content")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                TextEditor(text: $content)
                    .font(.body)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 200)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                
                Text("Paste your notes, conversation transcripts, or any relevant text")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private var existingSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Existing Sources")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(manager.contextSources.count)")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            
            ForEach(manager.contextSources.prefix(5)) { source in
                sourceCard(source)
            }
            
            if manager.contextSources.count > 5 {
                Text("+ \(manager.contextSources.count - 5) more sources")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func sourceCard(_ source: ContextSource) -> some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon(source.sourceType))
                .foregroundColor(.cyan)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title.isEmpty ? typeName(source.sourceType) : source.title)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(source.ingestedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { manager.deleteContext(source) }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func typeIcon(_ type: ContextType) -> String {
        switch type {
        case .manual: return "text.alignleft"
        case .note: return "note.text"
        case .conversation: return "bubble.left.and.bubble.right"
        case .document: return "doc.text"
        }
    }
    
    private func typeName(_ type: ContextType) -> String {
        switch type {
        case .manual: return "Text"
        case .note: return "Note"
        case .conversation: return "Chat"
        case .document: return "Doc"
        }
    }
    
    private func saveContext() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        let source = ContextSource(
            sourceType: selectedType,
            title: title.trimmingCharacters(in: .whitespaces),
            content: trimmedContent
        )
        
        manager.addContext(source)
        dismiss()
    }
}

#Preview {
    ContextImportView(manager: ARISEManager())
}

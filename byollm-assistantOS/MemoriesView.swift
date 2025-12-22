//
//  MemoriesView.swift
//  byollm-assistantOS
//
//  Created by master on 12/22/25.
//

import SwiftUI

struct Memory: Identifiable, Codable {
    let id: UUID
    var content: String
    var createdAt: Date
    var isEnabled: Bool
    
    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), isEnabled: Bool = true) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.isEnabled = isEnabled
    }
}

class MemoriesStore: ObservableObject {
    @Published var memories: [Memory] = []
    
    private let key = "userMemories"
    
    init() {
        load()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Memory].self, from: data) {
            memories = decoded
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func add(_ content: String) {
        let memory = Memory(content: content)
        memories.insert(memory, at: 0)
        save()
    }
    
    func delete(at offsets: IndexSet) {
        memories.remove(atOffsets: offsets)
        save()
    }
    
    func delete(_ memory: Memory) {
        memories.removeAll { $0.id == memory.id }
        save()
    }
    
    func toggle(_ memory: Memory) {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index].isEnabled.toggle()
            save()
        }
    }
    
    func enabledMemories() -> [Memory] {
        memories.filter { $0.isEnabled }
    }
}

struct MemoriesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = MemoriesStore()
    @State private var newMemoryText = ""
    @State private var showingAddMemory = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Memories")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showingAddMemory = true }) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                // Description
                Text("Memories help the AI remember important information about you across conversations.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
                
                if store.memories.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No memories yet")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Text("Tap + to add your first memory")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.3))
                    }
                    
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.memories) { memory in
                                MemoryRow(memory: memory, store: store)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemorySheet(store: store)
        }
    }
}

struct MemoryRow: View {
    let memory: Memory
    @ObservedObject var store: MemoriesStore
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Toggle
            Button(action: { store.toggle(memory) }) {
                Image(systemName: memory.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(memory.isEnabled ? .green : .white.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(.body)
                    .foregroundColor(memory.isEnabled ? .white : .white.opacity(0.5))
                    .lineLimit(3)
                
                Text(memory.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { showingDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .confirmationDialog("Delete Memory", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                store.delete(memory)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

struct AddMemorySheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: MemoriesStore
    @State private var memoryText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Add a memory that the AI should remember about you.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    ZStack(alignment: .topLeading) {
                        if memoryText.isEmpty {
                            Text("e.g., I prefer concise responses...")
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        
                        TextEditor(text: $memoryText)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .focused($isFocused)
                    }
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    Button(action: {
                        if !memoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            store.add(memoryText.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }) {
                        Text("Save Memory")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(memoryText.isEmpty ? Color.white.opacity(0.3) : Color.white)
                            .cornerRadius(12)
                    }
                    .disabled(memoryText.isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    MemoriesView()
}

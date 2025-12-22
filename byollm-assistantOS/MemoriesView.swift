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
    
    func deleteAll() {
        memories.removeAll()
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
    
    func search(_ query: String) -> [Memory] {
        if query.isEmpty {
            return memories
        }
        return memories.filter { $0.content.localizedCaseInsensitiveContains(query) }
    }
}

struct MemoriesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = MemoriesStore()
    @State private var searchText = ""
    @State private var showingAddMemory = false
    @State private var showingMenu = false
    @State private var showingDeleteAllConfirm = false
    
    var filteredMemories: [Memory] {
        store.search(searchText)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Saved memories")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Menu {
                        Button(action: { showingAddMemory = true }) {
                            Label("Add Memory", systemImage: "plus")
                        }
                        Button(role: .destructive, action: { showingDeleteAllConfirm = true }) {
                            Label("Delete All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 16)
                
                if store.memories.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("No memories yet")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        
                        Button(action: { showingAddMemory = true }) {
                            Text("Add your first memory")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    
                    Spacer()
                } else {
                    // Memories List
                    ScrollView {
                        VStack(spacing: 0) {
                            // Memory cards in a container
                            VStack(spacing: 0) {
                                ForEach(Array(filteredMemories.enumerated()), id: \.element.id) { index, memory in
                                    MemoryCard(memory: memory, store: store)
                                    
                                    if index < filteredMemories.count - 1 {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 100)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Search bar at bottom
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.4))
                        
                        TextField("Search", text: $searchText)
                            .foregroundColor(.white)
                            .placeholder(when: searchText.isEmpty) {
                                Text("Search")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemorySheet(store: store)
        }
        .confirmationDialog("Delete All Memories", isPresented: $showingDeleteAllConfirm) {
            Button("Delete All", role: .destructive) {
                store.deleteAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete all memories? This cannot be undone.")
        }
    }
}

struct MemoryCard: View {
    let memory: Memory
    @ObservedObject var store: MemoriesStore
    @State private var showingDeleteConfirm = false
    
    var body: some View {
        Text(memory.content)
            .font(.body)
            .foregroundColor(.white.opacity(0.9))
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive, action: { store.delete(memory) }) {
                    Label("Delete", systemImage: "trash")
                }
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

// Placeholder modifier for TextField
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    MemoriesView()
}

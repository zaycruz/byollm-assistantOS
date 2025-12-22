//
//  MemoriesView.swift
//  byollm-assistantOS
//
//  Created by master on 12/22/25.
//

import SwiftUI

// MARK: - API Response Models
struct Memory: Identifiable, Codable {
    let id: Int
    let content: String
    let confidence: Double?
    let accessCount: Int?
    let importanceScore: Double?
    let createdAt: String
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, content, confidence, tags
        case accessCount = "access_count"
        case importanceScore = "importance_score"
        case createdAt = "created_at"
    }
}

struct MemoriesListResponse: Codable {
    let memories: [Memory]
    let limit: Int
    let offset: Int
    let sortBy: String?
    
    enum CodingKeys: String, CodingKey {
        case memories, limit, offset
        case sortBy = "sort_by"
    }
}

struct MemorySearchResult: Codable {
    let id: Int
    let content: String
    let relevanceScore: Double?
    let confidence: Double?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, content, confidence
        case relevanceScore = "relevance_score"
        case createdAt = "created_at"
    }
}

struct MemorySearchResponse: Codable {
    let results: [MemorySearchResult]
    let query: String
    let total: Int
}

struct MemoryDeleteResponse: Codable {
    let status: String
    let memoryId: Int?
    
    enum CodingKeys: String, CodingKey {
        case status
        case memoryId = "memory_id"
    }
}

// MARK: - Memories Store
class MemoriesStore: ObservableObject {
    @Published var memories: [Memory] = []
    @Published var searchResults: [MemorySearchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var serverAddress: String {
        var address = UserDefaults.standard.string(forKey: "serverAddress")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Return empty if not configured
        guard !address.isEmpty else { return "" }
        
        // Add http:// prefix if missing
        if !address.hasPrefix("http://") && !address.hasPrefix("https://") {
            address = "http://\(address)"
        }
        
        return address
    }
    
    // MARK: - List Memories
    func fetchMemories() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        guard !serverAddress.isEmpty else {
            await MainActor.run {
                errorMessage = "Server not configured. Please set your server address in Settings."
                isLoading = false
            }
            return
        }
        
        let urlString = "\(serverAddress)/v1/memory/semantic?sort_by=recent&limit=100&offset=0"
        guard let url = URL(string: urlString) else {
            await MainActor.run { 
                errorMessage = "Invalid server URL"
                isLoading = false 
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run { 
                    errorMessage = "Invalid response"
                    isLoading = false 
                }
                return
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let listResponse = try decoder.decode(MemoriesListResponse.self, from: data)
                await MainActor.run {
                    self.memories = listResponse.memories
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Server error: \(httpResponse.statusCode)"
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to fetch memories: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Search Memories
    func searchMemories(query: String) async {
        guard !query.isEmpty else {
            await fetchMemories()
            return
        }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        guard !serverAddress.isEmpty else {
            await MainActor.run {
                errorMessage = "Server not configured"
                isLoading = false
            }
            return
        }
        
        let urlString = "\(serverAddress)/v1/memory/search"
        guard let url = URL(string: urlString) else {
            await MainActor.run { 
                errorMessage = "Invalid server URL"
                isLoading = false 
            }
            return
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "query": query,
                "limit": 20,
                "semantic_only": true
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                await MainActor.run { 
                    errorMessage = "Search failed"
                    isLoading = false 
                }
                return
            }
            
            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(MemorySearchResponse.self, from: data)
            await MainActor.run {
                self.searchResults = searchResponse.results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Search error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Delete Memory
    func deleteMemory(id: Int) async -> Bool {
        guard !serverAddress.isEmpty else { return false }
        
        let urlString = "\(serverAddress)/v1/memory/semantic/\(id)"
        guard let url = URL(string: urlString) else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return false
            }
            
            // Remove from local list
            await MainActor.run {
                self.memories.removeAll { $0.id == id }
                self.searchResults.removeAll { $0.id == id }
            }
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Delete All
    func deleteAll() async {
        for memory in memories {
            _ = await deleteMemory(id: memory.id)
        }
    }
}

struct MemoriesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var store = MemoriesStore()
    @State private var searchText = ""
    @State private var showingDeleteAllConfirm = false
    @State private var searchTask: Task<Void, Never>?
    
    var displayMemories: [Memory] {
        if !searchText.isEmpty && !store.searchResults.isEmpty {
            // Convert search results to Memory format for display
            return store.searchResults.map { result in
                Memory(
                    id: result.id,
                    content: result.content,
                    confidence: result.confidence,
                    accessCount: nil,
                    importanceScore: nil,
                    createdAt: result.createdAt,
                    tags: nil
                )
            }
        }
        return store.memories
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
                        Button(action: { Task { await store.fetchMemories() } }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
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
                
                if store.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = store.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange.opacity(0.7))
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button(action: { Task { await store.fetchMemories() } }) {
                            Text("Try Again")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(20)
                        }
                    }
                    Spacer()
                } else if displayMemories.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text(searchText.isEmpty ? "No memories yet" : "No results found")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                        
                        if searchText.isEmpty {
                            Text("Memories are created automatically from your conversations")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.3))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    
                    Spacer()
                } else {
                    // Memories List
                    ScrollView {
                        VStack(spacing: 0) {
                            // Memory cards in a container
                            VStack(spacing: 0) {
                                ForEach(Array(displayMemories.enumerated()), id: \.element.id) { index, memory in
                                    MemoryCard(memory: memory, store: store)
                                    
                                    if index < displayMemories.count - 1 {
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
                        .onChange(of: searchText) { _, newValue in
                            // Debounce search
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                                if !Task.isCancelled {
                                    await store.searchMemories(query: newValue)
                                }
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: { 
                            searchText = ""
                            Task { await store.fetchMemories() }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.4))
                        }
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
        .onAppear {
            Task { await store.fetchMemories() }
        }
        .confirmationDialog("Delete All Memories", isPresented: $showingDeleteAllConfirm) {
            Button("Delete All", role: .destructive) {
                Task { await store.deleteAll() }
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
                Button(role: .destructive, action: { 
                    Task { await store.deleteMemory(id: memory.id) }
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog("Delete Memory", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    Task { await store.deleteMemory(id: memory.id) }
                }
                Button("Cancel", role: .cancel) { }
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


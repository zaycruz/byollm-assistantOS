//
//  byollm_assistantOSApp.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI
import SwiftData

@main
struct byollm_assistantOSApp: App {
    private let modelContainer: ModelContainer
    
    init() {
        let schema = Schema([
            LevelUpGoal.self,
            LevelUpObjective.self,
            LevelUpContext.self,
            LevelUpUserProgress.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Migration failed - try to recover by deleting the store
            print("SwiftData migration failed: \(error). Attempting recovery...")
            
            // Delete the existing store
            let storeURL = config.url
            let fileManager = FileManager.default
            let storePath = storeURL.path
            
            // Delete main store and associated files
            for suffix in ["", "-shm", "-wal"] {
                let filePath = storePath + suffix
                if fileManager.fileExists(atPath: filePath) {
                    try? fileManager.removeItem(atPath: filePath)
                    print("Deleted: \(filePath)")
                }
            }
            
            // Retry creating the container
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
                print("SwiftData recovery successful - store recreated")
            } catch {
                fatalError("Failed to create SwiftData ModelContainer after recovery: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

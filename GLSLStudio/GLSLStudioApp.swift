//
//  GLSLStudioApp.swift
//  GLSLStudio
//
//  Created by Minsang Choi on 7/26/25.
//

import SwiftUI
import SwiftData

@main
struct GLSLStudioApp: App {
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: ShaderProject.self, ShaderFile.self)
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

//
//  ContentView.swift
//  GLSLStudio
//
//  Created by Minsang Choi on 7/26/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var projectsViewModel = ProjectsViewModel()
    @StateObject private var autoSaveService = AutoSaveService()
    @State private var selectedProject: ShaderProject?
    @State private var showNewProjectSheet = false
    
    var body: some View {
        NavigationSplitView {
            ProjectListView(
                selectedProject: $selectedProject,
                showNewProjectSheet: $showNewProjectSheet
            )
            .environmentObject(projectsViewModel)
        } detail: {
            if let project = selectedProject {
                SplitEditorView(project: project)
                    .environmentObject(projectsViewModel)
                    .environmentObject(autoSaveService)
            } else {
                EmptyProjectView()
            }
        }
        .sheet(isPresented: $showNewProjectSheet) {
            NewProjectSheet(selectedProject: $selectedProject)
                .environmentObject(projectsViewModel)
        }
        .glslStudioKeyboardShortcuts(
            projectsViewModel: projectsViewModel,
            selectedProject: $selectedProject,
            showNewProjectSheet: $showNewProjectSheet
        )
        .onAppear {
            projectsViewModel.setModelContext(modelContext)
            projectsViewModel.connectAutoSave(autoSaveService)
        }
    }
}

#Preview {
    ContentView()
}

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
            if let project = selectedProject,
               projectsViewModel.projects.contains(where: { $0.id == project.id }) {
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
        .onChange(of: projectsViewModel.projects) { oldValue, newValue in
            // Clear selected project if it no longer exists
            if let selected = selectedProject,
               !newValue.contains(where: { $0.id == selected.id }) {
                selectedProject = nil
            }
        }
        .onChange(of: selectedProject) { oldValue, newValue in
            // Cancel operations for the old project when switching projects
            if let oldProject = oldValue, let newProject = newValue, oldProject.id != newProject.id {
                print("🔄 ContentView: Project switching from \(oldProject.name) to \(newProject.name)")
                WebGLService.shared.cancelOperationsForProject(oldProject.id)
            } else if let oldProject = oldValue, newValue == nil {
                print("🔄 ContentView: Project \(oldProject.name) deselected")
                WebGLService.shared.cancelOperationsForProject(oldProject.id)
            }
        }
        .tint(.primary)
    }
}

#Preview {
    ContentView()
}

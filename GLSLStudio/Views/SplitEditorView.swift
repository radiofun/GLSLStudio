import SwiftUI

struct SplitEditorView: View {
    let project: ShaderProject
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    @State private var selectedShaderFile: ShaderFile?
    @State private var previewRefreshTrigger = 0
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                EditorTabView(
                    project: project,
                    selectedShaderFile: $selectedShaderFile
                )
                .frame(minWidth: 400)
            }
                        
            VStack(spacing: 0) {
                PreviewView(
                    project: project, 
                    selectedShaderFile: selectedShaderFile
                )
                    .frame(minWidth: 400)
                    .id("\(project.id)-\(previewRefreshTrigger)") // Force recreation when project changes or refresh trigger
                    .onChange(of: previewRefreshTrigger) { oldValue, newValue in
                        print("🔄 SplitEditorView: PreviewView ID changing due to refresh trigger: \(oldValue) -> \(newValue)")
                    }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ProjectToolbarView(
                    project: project,
                    onFullScreenDismiss: {
                        // Trigger preview refresh when returning from full screen
                        let oldTrigger = previewRefreshTrigger
                        previewRefreshTrigger += 1
                        print("🔄 SplitEditorView: Triggering preview refresh after full screen dismiss (trigger: \(oldTrigger) -> \(previewRefreshTrigger))")
                    }
                )
            }
        }
        .onAppear {
            if selectedShaderFile == nil {
                selectedShaderFile = project.fragmentShader
            }
        }
    }
}

struct EditorTabView: View {
    let project: ShaderProject
    @Binding var selectedShaderFile: ShaderFile?
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    var body: some View {
        TabView(selection: $selectedShaderFile) {
            ForEach(project.shaderFiles, id: \.id) { shaderFile in
                ShaderCodeEditor(
                    shaderFile: shaderFile,
                    onContentChange: { content in
                        projectsViewModel.updateShaderContent(shaderFile, content: content)
                    }
                )
                .tabItem {
                    Label(shaderFile.type.displayName, systemImage: shaderFile.type == .vertex ? "v.circle" : "f.circle")
                }
                .tag(shaderFile as ShaderFile?)

            }
        }
    }
}


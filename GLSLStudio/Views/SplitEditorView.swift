import SwiftUI

struct SplitEditorView: View {
    let project: ShaderProject
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    @State private var selectedShaderFile: ShaderFile?
    @State private var shaderUpdateTrigger = 0
    
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
                PreviewView(project: project)
                    .frame(minWidth: 400)
                    .id(shaderUpdateTrigger) // Force refresh when trigger changes
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                ProjectToolbarView(project: project)
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


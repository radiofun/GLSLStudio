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
            
            Divider()
            
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(project.shaderFiles, id: \.id) { shaderFile in
                    EditorTab(
                        shaderFile: shaderFile,
                        isSelected: selectedShaderFile?.id == shaderFile.id
                    ) {
                        selectedShaderFile = shaderFile
                    }
                }
                Spacer()
            }
            .background(Color(.systemGray6))
            
            if let selectedFile = selectedShaderFile {
                ShaderCodeEditor(
                    shaderFile: selectedFile,
                    onContentChange: { content in
                        projectsViewModel.updateShaderContent(selectedFile, content: content)
                    }
                )
            } else {
                EmptyCodeEditorView()
            }
        }
    }
}

struct EditorTab: View {
    let shaderFile: ShaderFile
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Circle()
                    .fill(shaderFile.type == .vertex ? Color.blue : Color.orange)
                    .frame(width: 8, height: 8)
                
                Text(shaderFile.type.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color(.systemBackground) : Color.clear
            )
            .cornerRadius(8, corners: [.topLeft, .topRight])
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyCodeEditorView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a shader file to edit")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
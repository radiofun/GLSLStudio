import SwiftUI

struct ShaderCodeEditor: View {
    let shaderFile: ShaderFile
    let onContentChange: (String) -> Void
    
    @State private var content: String
    @State private var isEditing = false
    @EnvironmentObject var autoSaveService: AutoSaveService
    
    init(shaderFile: ShaderFile, onContentChange: @escaping (String) -> Void) {
        self.shaderFile = shaderFile
        self.onContentChange = onContentChange
        self._content = State(initialValue: shaderFile.content)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(shaderFile.type.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isEditing {
                    Text("Editing...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            GLSLTextEditorView(
                text: $content,
                isEditing: $isEditing
            )
            .onChange(of: content) { oldValue, newValue in
                onContentChange(newValue)
                autoSaveService.markAsChanged()
                print("✏️ Editor: Content changed for \(shaderFile.type.displayName)")
                print("📝 New content (first 100 chars): \(String(newValue.prefix(100)))")
            }
        }
        .onAppear {
            content = shaderFile.content
            print("📄 Editor: Loading \(shaderFile.type.displayName) shader content")
            print("📝 Content (first 100 chars): \(String(content.prefix(100)))")
        }
        .onChange(of: shaderFile.id) { oldValue, newValue in
            content = shaderFile.content
            print("🔄 Editor: Shader file changed to \(shaderFile.type.displayName)")
            print("📝 New content (first 100 chars): \(String(content.prefix(100)))")
        }
        .onChange(of: shaderFile.content) { oldValue, newValue in
            if content != newValue {
                content = newValue
                print("🔄 Editor: Content updated from SwiftData for \(shaderFile.type.displayName)")
                print("📝 Updated content (first 100 chars): \(String(newValue.prefix(100)))")
            }
        }
    }
}

// GLSLTextEditor replaced with GLSLTextEditorView for syntax highlighting
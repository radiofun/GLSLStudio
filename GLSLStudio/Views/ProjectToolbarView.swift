import SwiftUI
import WebKit

struct ProjectToolbarView: View {
    let project: ShaderProject
    let onFullScreenDismiss: (() -> Void)?
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    @State private var showingRenameAlert = false
    @State private var newProjectName = ""
    @State private var showingFullScreenPreview = false
    
    init(project: ShaderProject, onFullScreenDismiss: (() -> Void)? = nil) {
        self.project = project
        self.onFullScreenDismiss = onFullScreenDismiss
    }
    
    var body: some View {
        HStack(spacing: 8) {
            
            
            Button(action: {
                projectsViewModel.saveProject(project)
            }) {
                Text("Save")
                    .bold()
                    .foregroundStyle(.primary)
            }


            Button(action: {
                showingFullScreenPreview = true
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .foregroundColor(.primary)
            }
            
            Menu {
                Button(action: { showingRenameAlert = true }) {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button(action: {
                    _ = projectsViewModel.duplicateProject(project)
                }) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.primary)
            }
            
            
        }
        .alert("Rename Project", isPresented: $showingRenameAlert) {
            TextField("Project Name", text: $newProjectName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    project.name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    projectsViewModel.saveProject(project)
                }
            }
        } message: {
            Text("Enter a new name for this project")
        }
        .fullScreenCover(isPresented: $showingFullScreenPreview) {
            FullScreenPreviewView(project: project)
        }
        .onChange(of: showingFullScreenPreview) { oldValue, newValue in
            // When returning from full screen, cleanup and trigger refresh
            if oldValue == true && newValue == false {
                print("🔄 Full screen dismissed for project: \(project.name) (ID: \(project.id))")
                print("🔄 Cleaning up shared WebGL service...")
                
                // First, force cleanup of the shared WebGL service
                WebGLService.shared.forceCleanup()
                
                // Then trigger the refresh after a longer delay to ensure cleanup is complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Triggering preview refresh for project: \(project.name) (ID: \(project.id))")
                    onFullScreenDismiss?()
                }
            }
        }
        .onAppear {
            newProjectName = project.name
        }
    }
}


struct FullScreenPreviewView: View {
    let project: ShaderProject
    @Environment(\.dismiss) private var dismiss
    @StateObject private var fullScreenWebGLService = WebGLService()
    @AppStorage("show_fps_preference") private var showFPS = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            FullScreenWebGLPreviewView(
                project: project,
                showFPS: $showFPS,
                webGLService: fullScreenWebGLService
            )
            .ignoresSafeArea()
            .onChange(of: project.vertexShader?.content) { oldValue, newValue in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fullScreenWebGLService.updateShaders(
                        vertexShader: project.vertexShader?.content ?? "",
                        fragmentShader: project.fragmentShader?.content ?? "",
                        forProject: project.id
                    )
                }
            }
            .onChange(of: project.fragmentShader?.content) { oldValue, newValue in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    fullScreenWebGLService.updateShaders(
                        vertexShader: project.vertexShader?.content ?? "",
                        fragmentShader: project.fragmentShader?.content ?? "",
                        forProject: project.id
                    )
                }
            }
            
            if let error = fullScreenWebGLService.compileError {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Shader Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            
                            ScrollView {
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 8)
                    
                    Spacer()
                }
                .padding()
            }
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    

                    Spacer()
                    
                    if showFPS {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("FPS: \(Int(fullScreenWebGLService.fps))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                            Text("Render: \(String(format: "%.1f", fullScreenWebGLService.renderTime))ms")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
}

struct FullScreenWebGLPreviewView: UIViewRepresentable {
    let project: ShaderProject
    @Binding var showFPS: Bool
    let webGLService: WebGLService
    
    func makeUIView(context: Context) -> WKWebView {
        print("🏗️ FullScreenWebGLPreviewView: Creating WebView for project: \(project.name) (ID: \(project.id))")
        let webView = webGLService.setupWebView(for: project.id)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("⏰ FullScreenWebGLPreviewView: Attempting shader load for project: \(project.name)")
            updateShaders()
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webGLService.setGeometry(.quad)
    }
    
    private func updateShaders() {
        guard let vertexShader = project.vertexShader,
              let fragmentShader = project.fragmentShader else { 
            print("❌ FullScreenWebGLPreviewView: No shaders found in project: \(project.name)")
            return 
        }
        
        print("🔄 FullScreenWebGLPreviewView: Updating shaders for project: \(project.name) (ID: \(project.id))")
        
        webGLService.updateShaders(
            vertexShader: vertexShader.content,
            fragmentShader: fragmentShader.content,
            forProject: project.id
        )
    }
}

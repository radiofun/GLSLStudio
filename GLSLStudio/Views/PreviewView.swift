import SwiftUI
import WebKit

struct PreviewView: View {
    let project: ShaderProject
    let selectedShaderFile: ShaderFile?
    @ObservedObject private var webGLService = WebGLService.shared
    @State private var showingControls = false
    @AppStorage("show_fps_preference") private var showFPS = true
    @State private var captureWorkItems: [DispatchWorkItem] = []
    @State private var hasCapturedInSession = false
    @State private var contentChangeTimer: Timer?
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                WebGLPreviewView(
                    project: project,
                    showFPS: $showFPS
                )
                
                
                if let error = webGLService.compileError {
                    ErrorOverlay(error: error)
                }
                
                if showingControls {
                    UniformControlsView(
                        webGLService: webGLService,
                        project: project
                    )
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        if showFPS {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("FPS: \(Int(webGLService.fps))")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("Render: \(String(format: "%.1f", webGLService.renderTime))ms")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .onChange(of: project.vertexShader?.content) { oldValue, newValue in
                print("🔄 Vertex shader content changed for project: \(project.name)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    webGLService.updateShaders(
                        vertexShader: project.vertexShader?.content ?? "",
                        fragmentShader: project.fragmentShader?.content ?? "",
                        forProject: project.id
                    )
                    // Debounced thumbnail capture when content changes
                    if oldValue != nil && oldValue != newValue {
                        debouncedCaptureThumbnail()
                    }
                }
            }
            .onChange(of: project.fragmentShader?.content) { oldValue, newValue in
                print("🔄 Fragment shader content changed for project: \(project.name)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    webGLService.updateShaders(
                        vertexShader: project.vertexShader?.content ?? "",
                        fragmentShader: project.fragmentShader?.content ?? "",
                        forProject: project.id
                    )
                    // Debounced thumbnail capture when content changes
                    if oldValue != nil && oldValue != newValue {
                        debouncedCaptureThumbnail()
                    }
                }
            }
            .onAppear {
                print("👁️ PreviewView appeared for project: \(project.name) (ID: \(project.id))")
                print("👁️ PreviewView: WebGL service ready state: \(webGLService.isReady)")
                
                // Only capture thumbnail on first view if project doesn't have one and hasn't been captured in this session
                if project.thumbnailData == nil && !hasCapturedInSession {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        captureThumbnail()
                        hasCapturedInSession = true
                    }
                }
            }
            .onDisappear {
                print("👋 PreviewView disappeared for project: \(project.name) (ID: \(project.id))")
                // Cancel any pending captures and timers
                captureWorkItems.forEach { $0.cancel() }
                captureWorkItems.removeAll()
                contentChangeTimer?.invalidate()
                contentChangeTimer = nil
            }
        }
    }
    
    private func captureThumbnail() {
        print("🖼️ Capturing thumbnail for project: \(project.name) (ID: \(project.id))")
        
        let workItem = DispatchWorkItem {
            webGLService.captureFrame { image in
                if let image = image, let thumbnailData = image.pngData() {
                    print("📸 Thumbnail captured successfully for project: \(project.name)")
                    projectsViewModel.updateProjectThumbnail(project, thumbnailData: thumbnailData)
                } else {
                    print("❌ Failed to capture thumbnail for project: \(project.name)")
                }
            }
        }
        
        captureWorkItems.append(workItem)
        
        // Wait a moment for the render to complete, then capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    private func debouncedCaptureThumbnail() {
        // Cancel existing timer
        contentChangeTimer?.invalidate()
        
        // Create new timer with 10 second delay to debounce rapid content changes
        contentChangeTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("⏱️ Debounced thumbnail capture triggered for project: \(project.name)")
            captureThumbnail()
        }
    }
}

struct WebGLPreviewView: UIViewRepresentable {
    let project: ShaderProject
    @Binding var showFPS: Bool
    
    private let webGLService = WebGLService.shared
    
    func makeUIView(context: Context) -> WKWebView {
        print("🏗️ WebGLPreviewView: Creating WebView for project: \(project.name) (ID: \(project.id))")
        
        // Force recreation to ensure fresh context (especially after returning from full screen)
        let webView = webGLService.setupWebView(for: project.id, forceRecreate: true)
        
        print("🏗️ WebGLPreviewView: WebView created, scheduling shader loads...")
        
        // Initial shader load - wait for WebGL to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("⏰ WebGLPreviewView: Attempting initial shader load for project: \(project.name)")
            updateShaders()
        }
        
        // Backup shader load in case the first one doesn't work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            print("🔄 WebGLPreviewView: Backup shader load attempt for project: \(project.name)")
            updateShaders()
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Default to quad geometry
        webGLService.setGeometry(.quad)
    }
    
    private func updateShaders() {
        guard let vertexShader = project.vertexShader,
              let fragmentShader = project.fragmentShader else { 
            print("❌ WebGLPreviewView: No shaders found in project: \(project.name) (ID: \(project.id))")
            return 
        }
        
        print("🔄 WebGLPreviewView: Updating shaders for project: \(project.name) (ID: \(project.id))")
        print("📝 Vertex shader (first 100 chars): \(String(vertexShader.content.prefix(100)))")
        print("📝 Fragment shader (first 100 chars): \(String(fragmentShader.content.prefix(100)))")
        print("🔄 WebGLPreviewView: Vertex shader file ID: \(vertexShader.id)")
        print("🔄 WebGLPreviewView: Fragment shader file ID: \(fragmentShader.id)")
        
        webGLService.updateShaders(
            vertexShader: vertexShader.content,
            fragmentShader: fragmentShader.content,
            forProject: project.id
        )
    }
}


struct ErrorOverlay: View {
    let error: String
    
    var body: some View {
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
}

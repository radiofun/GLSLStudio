import SwiftUI
import WebKit

struct PreviewView: View {
    let project: ShaderProject
    let selectedShaderFile: ShaderFile?
    @ObservedObject private var webGLService = WebGLService.shared
    @State private var showingControls = false
    @State private var showFPS = true
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
                .onChange(of: project.vertexShader?.content) { oldValue, newValue in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        webGLService.updateShaders(
                            vertexShader: project.vertexShader?.content ?? "",
                            fragmentShader: project.fragmentShader?.content ?? ""
                        )
                        // Debounced thumbnail capture when content changes
                        if oldValue != nil && oldValue != newValue {
                            debouncedCaptureThumbnail()
                        }
                    }
                }
                .onChange(of: project.fragmentShader?.content) { oldValue, newValue in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        webGLService.updateShaders(
                            vertexShader: project.vertexShader?.content ?? "",
                            fragmentShader: project.fragmentShader?.content ?? ""
                        )
                        // Debounced thumbnail capture when content changes
                        if oldValue != nil && oldValue != newValue {
                            debouncedCaptureThumbnail()
                        }
                    }
                }
                
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
                            .onTapGesture {
                                showFPS = false
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .onTapGesture(count: 2) {
                if !showFPS {
                    showFPS = true
                }
            }
            .onAppear {
                print("👁️ PreviewView appeared for project: \(project.name) (ID: \(project.id))")
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
        let webView = webGLService.setupWebView(for: project.id)
        
        // Initial shader load - wait for WebGL to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
            print("❌ Preview: No shaders found in project")
            return 
        }
        
        print("🔄 Preview: Updating shaders...")
        print("📝 Vertex shader (first 100 chars): \(String(vertexShader.content.prefix(100)))")
        print("📝 Fragment shader (first 100 chars): \(String(fragmentShader.content.prefix(100)))")
        
        webGLService.updateShaders(
            vertexShader: vertexShader.content,
            fragmentShader: fragmentShader.content
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

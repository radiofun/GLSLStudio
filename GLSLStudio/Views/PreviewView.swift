import SwiftUI
import WebKit

struct PreviewView: View {
    let project: ShaderProject
    @StateObject private var webGLService = WebGLService()
    @State private var showingControls = false
    
    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                WebGLPreviewView(
                    project: project,
                    webGLService: webGLService
                )
                .onChange(of: project.vertexShader?.content) { oldValue, newValue in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        webGLService.updateShaders(
                            vertexShader: project.vertexShader?.content ?? "",
                            fragmentShader: project.fragmentShader?.content ?? ""
                        )
                    }
                }
                .onChange(of: project.fragmentShader?.content) { oldValue, newValue in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        webGLService.updateShaders(
                            vertexShader: project.vertexShader?.content ?? "",
                            fragmentShader: project.fragmentShader?.content ?? ""
                        )
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
            }
        }
    }
}

struct WebGLPreviewView: UIViewRepresentable {
    let project: ShaderProject
    let webGLService: WebGLService
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = webGLService.setupWebView()
        
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

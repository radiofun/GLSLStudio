import Foundation
import WebKit

class WebGLService: NSObject, ObservableObject {
    static let shared = WebGLService()
    
    private var webView: WKWebView?
    private var messageHandler: WebGLMessageHandler?
    private var currentProjectId: UUID?
    private var operationId = UUID() // Unique ID for each WebGL context session
    private var pendingOperations: Set<UUID> = []
    
    @Published var isReady = false
    @Published var compileError: String?
    @Published var fps: Double = 0
    @Published var renderTime: Double = 0
    
    override init() {
        super.init()
    }
    
    func setupWebView(for projectId: UUID, forceRecreate: Bool = false) -> WKWebView {
        // Clean up existing WebView if switching projects or forced recreation
        if let existingView = webView, (currentProjectId != projectId || forceRecreate) {
            print("🔄 WebGLService: \(forceRecreate ? "Force recreating" : "Switching from project \(currentProjectId?.uuidString ?? "unknown") to") WebView for project: \(projectId.uuidString)")
            cleanupWebView()
        }
        
        // Reuse existing WebView if same project and not forced recreation
        if let existingView = webView, currentProjectId == projectId && !forceRecreate {
            print("♻️ WebGLService: Reusing existing WebView for project: \(projectId.uuidString)")
            return existingView
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        messageHandler = WebGLMessageHandler(service: self)
        configuration.userContentController.add(messageHandler!, name: "nativeHandler")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        self.webView = webView
        self.currentProjectId = projectId
        loadWebGLRuntime()
        
        print("🔄 WebGLService: Created new WebView for project: \(projectId)")
        
        return webView
    }
    
    private func cleanupWebView() {
        // Cancel all pending operations
        print("🧹 WebGLService: Cancelling \(pendingOperations.count) pending operations")
        pendingOperations.removeAll()
        
        // Invalidate current operation session
        operationId = UUID()
        
        if let webView = webView {
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeHandler")
            webView.removeFromSuperview()
            print("🧹 WebGLService: Cleaned up WebView for project: \(currentProjectId?.uuidString ?? "unknown")")
        }
        
        messageHandler = nil
        webView = nil
        currentProjectId = nil
        isReady = false
        compileError = nil
        fps = 0
        renderTime = 0
    }
    
    func updateShaders(vertexShader: String, fragmentShader: String, forProject projectId: UUID, retryCount: Int = 0) {
        guard let webView = webView else { 
            print("❌ WebGLService: No webView available for shader update")
            return 
        }
        
        // Validate that this operation is for the current project
        guard currentProjectId == projectId else {
            print("❌ WebGLService: Shader update cancelled - project mismatch (current: \(currentProjectId?.uuidString ?? "none"), requested: \(projectId.uuidString))")
            return
        }
        
        // Create unique operation ID for this shader update
        let operationUUID = UUID()
        let currentOperationId = operationId
        pendingOperations.insert(operationUUID)
        
        print("🔄 WebGLService: Updating shaders for project: \(projectId.uuidString), operation: \(operationUUID)")
        print("🔄 WebGLService: WebGL ready state: \(isReady), retry count: \(retryCount)")
        
        let escapedVertex = vertexShader.replacingOccurrences(of: "`", with: "\\`")
        let escapedFragment = fragmentShader.replacingOccurrences(of: "`", with: "\\`")
        
        let script = """
        if (window.glslStudio) {
            console.log('✅ GLSL Studio ready, updating shaders...');
            window.glslStudio.updateShaders(`\(escapedVertex)`, `\(escapedFragment)`);
            true; // Return success
        } else {
            console.log('⏳ GLSL Studio not ready yet, queuing shader update...');
            window.pendingShaders = {
                vertex: `\(escapedVertex)`,
                fragment: `\(escapedFragment)`
            };
            false; // Return not ready
        }
        """
        
        webView.evaluateJavaScript(script) { result, error in
            // Remove operation from pending set
            self.pendingOperations.remove(operationUUID)
            
            // Check if this operation is still valid (project and session haven't changed)
            guard self.currentProjectId == projectId && self.operationId == currentOperationId else {
                print("❌ WebGLService: Shader update result ignored - context changed (operation: \(operationUUID))")
                return
            }
            
            if let error = error {
                print("❌ WebGLService: Error updating shaders: \(error)")
            } else if let success = result as? Bool, success {
                print("✅ WebGLService: Shader update successful (operation: \(operationUUID))")
            } else if retryCount < 3 {
                print("⏳ WebGLService: WebGL not ready, retrying in 1 second (attempt \(retryCount + 1)/3)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.updateShaders(vertexShader: vertexShader, fragmentShader: fragmentShader, forProject: projectId, retryCount: retryCount + 1)
                }
            } else {
                print("❌ WebGLService: Failed to update shaders after 3 retries")
            }
        }
    }
    
    func setUniform(name: String, value: Any) {
        guard let webView = webView else { return }
        
        let script: String
        if let floatValue = value as? Float {
            script = "window.glslStudio?.setUniform('\(name)', \(floatValue));"
        } else if let vec2 = value as? [Float], vec2.count == 2 {
            script = "window.glslStudio?.setUniform('\(name)', [\(vec2[0]), \(vec2[1])]);"
        } else if let vec3 = value as? [Float], vec3.count == 3 {
            script = "window.glslStudio?.setUniform('\(name)', [\(vec3[0]), \(vec3[1]), \(vec3[2])]);"
        } else if let vec4 = value as? [Float], vec4.count == 4 {
            script = "window.glslStudio?.setUniform('\(name)', [\(vec4[0]), \(vec4[1]), \(vec4[2]), \(vec4[3])]);"
        } else {
            return
        }
        
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func setGeometry(_ geometry: GeometryType) {
        guard let webView = webView else { return }
        
        let script = "window.glslStudio?.setGeometry('\(geometry.rawValue)');"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }
    
    func captureFrame(completion: @escaping (UIImage?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        let script = "window.glslStudio?.captureFrame();"
        webView.evaluateJavaScript(script) { result, error in
            if let dataURL = result as? String,
               let data = Data(base64Encoded: String(dataURL.dropFirst(22))), // Remove "data:image/png;base64,"
               let image = UIImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }
    
    private func loadWebGLRuntime() {
        guard let webView = webView else { return }
        
        let html = createWebGLHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    func forceCleanup() {
        print("🧹 WebGLService: Force cleanup requested")
        cleanupWebView()
    }
    
    func cancelOperationsForProject(_ projectId: UUID) {
        if currentProjectId == projectId {
            print("🚫 WebGLService: Cancelling operations for current project: \(projectId.uuidString)")
            cleanupWebView()
        } else {
            print("🚫 WebGLService: Project \(projectId.uuidString) not current, no operations to cancel")
        }
    }
    
    deinit {
        cleanupWebView()
        print("🗑️ WebGLService: Deallocated")
    }
}

class WebGLMessageHandler: NSObject, WKScriptMessageHandler {
    weak var service: WebGLService?
    
    init(service: WebGLService) {
        self.service = service
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        DispatchQueue.main.async {
            switch type {
            case "ready":
                print("✅ WebGLService: Received 'ready' message from WebGL")
                self.service?.isReady = true
            case "error":
                if let error = body["message"] as? String {
                    print("❌ WebGLService: Received error: \(error)")
                    self.service?.compileError = error
                }
            case "clearError":
                print("🧹 WebGLService: Clearing error")
                self.service?.compileError = nil
            case "stats":
                if let fps = body["fps"] as? Double {
                    self.service?.fps = fps
                }
                if let renderTime = body["renderTime"] as? Double {
                    self.service?.renderTime = renderTime
                }
            default:
                print("🤷‍♂️ WebGLService: Unknown message type: \(type)")
                break
            }
        }
    }
}

enum GeometryType: String, CaseIterable {
    case quad = "quad"
    case triangle = "triangle"
    case cube = "cube"
    case sphere = "sphere"
    
    var displayName: String {
        switch self {
        case .quad: return "Quad"
        case .triangle: return "Triangle"
        case .cube: return "Cube"
        case .sphere: return "Sphere"
        }
    }
}

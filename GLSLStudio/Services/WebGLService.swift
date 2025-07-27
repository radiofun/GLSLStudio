import Foundation
import WebKit

class WebGLService: NSObject, ObservableObject {
    private var webView: WKWebView?
    private var messageHandler: WebGLMessageHandler?
    
    @Published var isReady = false
    @Published var compileError: String?
    @Published var fps: Double = 0
    @Published var renderTime: Double = 0
    
    func setupWebView() -> WKWebView {
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
        loadWebGLRuntime()
        
        return webView
    }
    
    func updateShaders(vertexShader: String, fragmentShader: String) {
        guard let webView = webView else { return }
        
        let escapedVertex = vertexShader.replacingOccurrences(of: "`", with: "\\`")
        let escapedFragment = fragmentShader.replacingOccurrences(of: "`", with: "\\`")
        
        let script = """
        if (window.glslStudio) {
            console.log('Updating shaders...');
            window.glslStudio.updateShaders(`\(escapedVertex)`, `\(escapedFragment)`);
        } else {
            console.log('GLSL Studio not ready yet, queuing shader update...');
            window.pendingShaders = {
                vertex: `\(escapedVertex)`,
                fragment: `\(escapedFragment)`
            };
        }
        """
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("Error updating shaders: \(error)")
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
                self.service?.isReady = true
            case "error":
                if let error = body["message"] as? String {
                    self.service?.compileError = error
                }
            case "clearError":
                self.service?.compileError = nil
            case "stats":
                if let fps = body["fps"] as? Double {
                    self.service?.fps = fps
                }
                if let renderTime = body["renderTime"] as? Double {
                    self.service?.renderTime = renderTime
                }
            default:
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
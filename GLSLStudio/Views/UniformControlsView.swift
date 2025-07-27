import SwiftUI

struct UniformControlsView: View {
    let webGLService: WebGLService
    let project: ShaderProject
    @State private var uniformValues: [String: UniformValue] = [:]
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                HStack {
                    Text("Shader Uniforms")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Reset") {
                        resetUniforms()
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(.systemGray6))
                
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(uniformValues.keys.sorted()), id: \.self) { uniformName in
                            if let uniform = uniformValues[uniformName] {
                                UniformControl(
                                    name: uniformName,
                                    uniform: uniform,
                                    onValueChange: { newValue in
                                        uniformValues[uniformName] = newValue
                                        updateWebGLUniform(name: uniformName, value: newValue)
                                    }
                                )
                            }
                        }
                        
                        if uniformValues.isEmpty {
                            Text("No custom uniforms detected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding()
        }
        .onAppear {
            detectUniforms()
        }
    }
    
    private func detectUniforms() {
        // Parse shader code for custom uniforms
        guard let fragmentShader = project.fragmentShader else { return }
        
        let uniformPattern = #"uniform\s+(\w+)\s+(\w+);"#
        let regex = try! NSRegularExpression(pattern: uniformPattern)
        let range = NSRange(fragmentShader.content.startIndex..., in: fragmentShader.content)
        
        var detectedUniforms: [String: UniformValue] = [:]
        
        regex.enumerateMatches(in: fragmentShader.content, range: range) { match, _, _ in
            guard let match = match,
                  let typeRange = Range(match.range(at: 1), in: fragmentShader.content),
                  let nameRange = Range(match.range(at: 2), in: fragmentShader.content) else { return }
            
            let type = String(fragmentShader.content[typeRange])
            let name = String(fragmentShader.content[nameRange])
            
            // Skip built-in uniforms
            if ["u_time", "u_resolution", "u_mouse"].contains(name) { return }
            
            switch type {
            case "float":
                detectedUniforms[name] = .float(0.0)
            case "vec2":
                detectedUniforms[name] = .vec2([0.0, 0.0])
            case "vec3":
                detectedUniforms[name] = .vec3([0.0, 0.0, 0.0])
            case "vec4":
                detectedUniforms[name] = .vec4([0.0, 0.0, 0.0, 1.0])
            default:
                break
            }
        }
        
        uniformValues = detectedUniforms
    }
    
    private func resetUniforms() {
        for (name, uniform) in uniformValues {
            let resetValue: UniformValue
            switch uniform {
            case .float(_):
                resetValue = .float(0.0)
            case .vec2(_):
                resetValue = .vec2([0.0, 0.0])
            case .vec3(_):
                resetValue = .vec3([0.0, 0.0, 0.0])
            case .vec4(_):
                resetValue = .vec4([0.0, 0.0, 0.0, 1.0])
            }
            
            uniformValues[name] = resetValue
            updateWebGLUniform(name: name, value: resetValue)
        }
    }
    
    private func updateWebGLUniform(name: String, value: UniformValue) {
        switch value {
        case .float(let f):
            webGLService.setUniform(name: name, value: f)
        case .vec2(let v):
            webGLService.setUniform(name: name, value: v)
        case .vec3(let v):
            webGLService.setUniform(name: name, value: v)
        case .vec4(let v):
            webGLService.setUniform(name: name, value: v)
        }
    }
}

enum UniformValue {
    case float(Float)
    case vec2([Float])
    case vec3([Float])
    case vec4([Float])
}

struct UniformControl: View {
    let name: String
    let uniform: UniformValue
    let onValueChange: (UniformValue) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            switch uniform {
            case .float(let value):
                FloatSlider(value: value, range: -10...10) { newValue in
                    onValueChange(.float(newValue))
                }
                
            case .vec2(let values):
                VStack(spacing: 4) {
                    FloatSlider(value: values[0], range: -10...10, label: "X") { newValue in
                        var newValues = values
                        newValues[0] = newValue
                        onValueChange(.vec2(newValues))
                    }
                    FloatSlider(value: values[1], range: -10...10, label: "Y") { newValue in
                        var newValues = values
                        newValues[1] = newValue
                        onValueChange(.vec2(newValues))
                    }
                }
                
            case .vec3(let values):
                VStack(spacing: 4) {
                    FloatSlider(value: values[0], range: -10...10, label: "X") { newValue in
                        var newValues = values
                        newValues[0] = newValue
                        onValueChange(.vec3(newValues))
                    }
                    FloatSlider(value: values[1], range: -10...10, label: "Y") { newValue in
                        var newValues = values
                        newValues[1] = newValue
                        onValueChange(.vec3(newValues))
                    }
                    FloatSlider(value: values[2], range: -10...10, label: "Z") { newValue in
                        var newValues = values
                        newValues[2] = newValue
                        onValueChange(.vec3(newValues))
                    }
                }
                
            case .vec4(let values):
                VStack(spacing: 4) {
                    FloatSlider(value: values[0], range: -10...10, label: "X") { newValue in
                        var newValues = values
                        newValues[0] = newValue
                        onValueChange(.vec4(newValues))
                    }
                    FloatSlider(value: values[1], range: -10...10, label: "Y") { newValue in
                        var newValues = values
                        newValues[1] = newValue
                        onValueChange(.vec4(newValues))
                    }
                    FloatSlider(value: values[2], range: -10...10, label: "Z") { newValue in
                        var newValues = values
                        newValues[2] = newValue
                        onValueChange(.vec4(newValues))
                    }
                    FloatSlider(value: values[3], range: 0...1, label: "W") { newValue in
                        var newValues = values
                        newValues[3] = newValue
                        onValueChange(.vec4(newValues))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct FloatSlider: View {
    let value: Float
    let range: ClosedRange<Float>
    let label: String?
    let onChange: (Float) -> Void
    
    @State private var localValue: Float
    
    init(value: Float, range: ClosedRange<Float>, label: String? = nil, onChange: @escaping (Float) -> Void) {
        self.value = value
        self.range = range
        self.label = label
        self.onChange = onChange
        self._localValue = State(initialValue: value)
    }
    
    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 12, alignment: .leading)
            }
            
            Slider(value: $localValue, in: range) { _ in
                onChange(localValue)
            }
            
            Text(String(format: "%.2f", localValue))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .onChange(of: value) { oldValue, newValue in
            localValue = newValue
        }
    }
}
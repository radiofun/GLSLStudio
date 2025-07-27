import SwiftUI

struct NewProjectSheet: View {
    @Binding var selectedProject: ShaderProject?
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var selectedTemplate: ShaderTemplate = .basic
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create New Project")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Name")
                            .font(.headline)
                        
                        TextField("Enter project name", text: $projectName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onAppear {
                                projectName = "Untitled Project \(projectsViewModel.projects.count + 1)"
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Template")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(ShaderTemplate.allCases, id: \.self) { template in
                                TemplateCard(
                                    template: template,
                                    isSelected: selectedTemplate == template
                                ) {
                                    selectedTemplate = template
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Create") {
                        createProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = projectsViewModel.createProject(name: trimmedName)
        
        if let vertexShader = project.vertexShader,
           let fragmentShader = project.fragmentShader {
            vertexShader.content = selectedTemplate.vertexShaderContent
            fragmentShader.content = selectedTemplate.fragmentShaderContent
            projectsViewModel.saveProject(project)
        }
        
        selectedProject = project
        dismiss()
    }
}

enum ShaderTemplate: String, CaseIterable {
    case basic = "Basic"
    case animated = "Animated"
    case raymarching = "Raymarching"
    case fractal = "Fractal"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .basic:
            return "Simple color gradient"
        case .animated:
            return "Time-based animation"
        case .raymarching:
            return "3D raymarching template"
        case .fractal:
            return "Mandelbrot fractal"
        }
    }
    
    var icon: String {
        switch self {
        case .basic:
            return "paintpalette"
        case .animated:
            return "play.circle"
        case .raymarching:
            return "cube"
        case .fractal:
            return "infinity"
        }
    }
    
    var vertexShaderContent: String {
        return """
attribute vec4 a_position;
attribute vec2 a_texcoord;

varying vec2 v_texcoord;

void main() {
    gl_Position = a_position;
    v_texcoord = a_texcoord;
}
"""
    }
    
    var fragmentShaderContent: String {
        switch self {
        case .basic:
            return """
precision mediump float;

uniform vec2 u_resolution;
varying vec2 v_texcoord;

void main() {
    vec2 uv = v_texcoord;
    vec3 color = vec3(uv.x, uv.y, 0.5);
    gl_FragColor = vec4(color, 1.0);
}
"""
        case .animated:
            return """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

void main() {
    vec2 uv = v_texcoord;
    vec3 color = 0.5 + 0.5 * cos(u_time + uv.xyx + vec3(0, 2, 4));
    gl_FragColor = vec4(color, 1.0);
}
"""
        case .raymarching:
            return """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

float sphere(vec3 p, float r) {
    return length(p) - r;
}

void main() {
    vec2 uv = (v_texcoord - 0.5) * 2.0;
    uv.x *= u_resolution.x / u_resolution.y;
    
    vec3 ro = vec3(0, 0, -3);
    vec3 rd = normalize(vec3(uv, 1));
    
    float t = 0.0;
    for (int i = 0; i < 64; i++) {
        vec3 p = ro + rd * t;
        float d = sphere(p, 1.0);
        if (d < 0.001) break;
        t += d;
    }
    
    vec3 color = vec3(1.0 - t * 0.1);
    gl_FragColor = vec4(color, 1.0);
}
"""
        case .fractal:
            return """
precision mediump float;

uniform float u_time;
uniform vec2 u_resolution;
varying vec2 v_texcoord;

vec2 complexMul(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

void main() {
    vec2 uv = (v_texcoord - 0.5) * 3.0;
    uv.x *= u_resolution.x / u_resolution.y;
    
    vec2 c = uv;
    vec2 z = vec2(0.0);
    
    int iterations = 0;
    for (int i = 0; i < 100; i++) {
        if (length(z) > 2.0) break;
        z = complexMul(z, z) + c;
        iterations = i;
    }
    
    float color = float(iterations) / 100.0;
    gl_FragColor = vec4(vec3(color), 1.0);
}
"""
        }
    }
}

struct TemplateCard: View {
    let template: ShaderTemplate
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: template.icon)
                .font(.title)
                .foregroundColor(isSelected ? .white : .accentColor)
            
            Text(template.displayName)
                .font(.headline)
                .foregroundColor(isSelected ? .white : .primary)
            
            Text(template.description)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(isSelected ? Color.accentColor : Color(.systemGray6))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}
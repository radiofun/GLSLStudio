import SwiftUI

struct DocumentationView: View {
    @State private var selectedCategory: DocumentationCategory = .builtin
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 0) {
                    ForEach(DocumentationCategory.allCases, id: \.self) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                                Spacer()
                            }
                            .padding()
                            .background(selectedCategory == category ? Color.accentColor : Color.clear)
                            .foregroundColor(selectedCategory == category ? .white : .primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                }
                .frame(width: 200)
                .background(Color(.systemGray6))
                
                // Content
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        TextField("Search documentation...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                    
                    // Documentation content
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(filteredItems, id: \.title) { item in
                                DocumentationItemView(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("GLSL Reference")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var filteredItems: [DocumentationItem] {
        let items = selectedCategory.items
        
        if searchText.isEmpty {
            return items
        } else {
            return items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

enum DocumentationCategory: CaseIterable {
    case builtin
    case functions
    case variables
    case examples
    
    var displayName: String {
        switch self {
        case .builtin: return "Built-in"
        case .functions: return "Functions"
        case .variables: return "Variables"
        case .examples: return "Examples"
        }
    }
    
    var icon: String {
        switch self {
        case .builtin: return "cube.box"
        case .functions: return "function"
        case .variables: return "x.squareroot"
        case .examples: return "lightbulb"
        }
    }
    
    var items: [DocumentationItem] {
        switch self {
        case .builtin:
            return GLSLDocumentation.builtinTypes
        case .functions:
            return GLSLDocumentation.functions
        case .variables:
            return GLSLDocumentation.variables
        case .examples:
            return GLSLDocumentation.examples
        }
    }
}

struct DocumentationItem {
    let title: String
    let description: String
    let syntax: String?
    let example: String?
    let category: String?
}

struct DocumentationItemView: View {
    let item: DocumentationItem
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let syntax = item.syntax {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Syntax")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(syntax)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let example = item.example {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Example")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(example)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct GLSLDocumentation {
    static let builtinTypes = [
        DocumentationItem(
            title: "vec2",
            description: "2-component floating point vector",
            syntax: "vec2 name = vec2(x, y);",
            example: "vec2 position = vec2(1.0, 2.0);",
            category: "types"
        ),
        DocumentationItem(
            title: "vec3",
            description: "3-component floating point vector",
            syntax: "vec3 name = vec3(x, y, z);",
            example: "vec3 color = vec3(1.0, 0.5, 0.0);",
            category: "types"
        ),
        DocumentationItem(
            title: "vec4",
            description: "4-component floating point vector",
            syntax: "vec4 name = vec4(x, y, z, w);",
            example: "vec4 color = vec4(1.0, 0.5, 0.0, 1.0);",
            category: "types"
        ),
        DocumentationItem(
            title: "float",
            description: "Single precision floating point",
            syntax: "float name = value;",
            example: "float intensity = 0.5;",
            category: "types"
        ),
        DocumentationItem(
            title: "mat4",
            description: "4x4 floating point matrix",
            syntax: "mat4 name = mat4(...);",
            example: "mat4 transform = mat4(1.0);",
            category: "types"
        )
    ]
    
    static let functions = [
        DocumentationItem(
            title: "sin(x)",
            description: "Returns the sine of x in radians",
            syntax: "float sin(float x)",
            example: "float wave = sin(u_time);",
            category: "math"
        ),
        DocumentationItem(
            title: "cos(x)",
            description: "Returns the cosine of x in radians",
            syntax: "float cos(float x)",
            example: "float wave = cos(u_time);",
            category: "math"
        ),
        DocumentationItem(
            title: "length(v)",
            description: "Returns the length of vector v",
            syntax: "float length(vec2/vec3/vec4 v)",
            example: "float dist = length(uv - center);",
            category: "geometric"
        ),
        DocumentationItem(
            title: "normalize(v)",
            description: "Returns the normalized vector v",
            syntax: "vec2/vec3/vec4 normalize(vec2/vec3/vec4 v)",
            example: "vec3 normal = normalize(direction);",
            category: "geometric"
        ),
        DocumentationItem(
            title: "mix(a, b, t)",
            description: "Linear interpolation between a and b by factor t",
            syntax: "type mix(type a, type b, float t)",
            example: "vec3 color = mix(red, blue, 0.5);",
            category: "common"
        ),
        DocumentationItem(
            title: "smoothstep(edge0, edge1, x)",
            description: "Smooth Hermite interpolation between 0 and 1",
            syntax: "float smoothstep(float edge0, float edge1, float x)",
            example: "float mask = smoothstep(0.2, 0.8, intensity);",
            category: "common"
        ),
        DocumentationItem(
            title: "dot(a, b)",
            description: "Returns the dot product of a and b",
            syntax: "float dot(vec2/vec3/vec4 a, vec2/vec3/vec4 b)",
            example: "float angle = dot(normal, light);",
            category: "geometric"
        ),
        DocumentationItem(
            title: "fract(x)",
            description: "Returns the fractional part of x",
            syntax: "float fract(float x)",
            example: "float pattern = fract(uv.x * 10.0);",
            category: "common"
        )
    ]
    
    static let variables = [
        DocumentationItem(
            title: "gl_Position",
            description: "Vertex shader output position (vertex shaders only)",
            syntax: "gl_Position = vec4(x, y, z, w);",
            example: "gl_Position = vec4(position, 1.0);",
            category: "builtin"
        ),
        DocumentationItem(
            title: "gl_FragColor",
            description: "Fragment shader output color (fragment shaders only)",
            syntax: "gl_FragColor = vec4(r, g, b, a);",
            example: "gl_FragColor = vec4(color, 1.0);",
            category: "builtin"
        ),
        DocumentationItem(
            title: "u_time",
            description: "Time in seconds since shader start (common uniform)",
            syntax: "uniform float u_time;",
            example: "float wave = sin(u_time);",
            category: "uniform"
        ),
        DocumentationItem(
            title: "u_resolution",
            description: "Screen resolution in pixels (common uniform)",
            syntax: "uniform vec2 u_resolution;",
            example: "vec2 uv = gl_FragCoord.xy / u_resolution;",
            category: "uniform"
        ),
        DocumentationItem(
            title: "u_mouse",
            description: "Mouse position in pixels (common uniform)",
            syntax: "uniform vec2 u_mouse;",
            example: "vec2 mouse = u_mouse / u_resolution;",
            category: "uniform"
        )
    ]
    
    static let examples = [
        DocumentationItem(
            title: "Simple Circle",
            description: "Draw a simple circle in the center",
            syntax: nil,
            example: """
vec2 uv = v_texcoord - 0.5;
float dist = length(uv);
float circle = step(dist, 0.3);
gl_FragColor = vec4(vec3(circle), 1.0);
""",
            category: "basic"
        ),
        DocumentationItem(
            title: "Animated Gradient",
            description: "Create a time-based animated gradient",
            syntax: nil,
            example: """
vec2 uv = v_texcoord;
vec3 color = 0.5 + 0.5 * cos(u_time + uv.xyx + vec3(0,2,4));
gl_FragColor = vec4(color, 1.0);
""",
            category: "animation"
        ),
        DocumentationItem(
            title: "Checkerboard",
            description: "Create a checkerboard pattern",
            syntax: nil,
            example: """
vec2 uv = v_texcoord * 8.0;
float checker = mod(floor(uv.x) + floor(uv.y), 2.0);
gl_FragColor = vec4(vec3(checker), 1.0);
""",
            category: "pattern"
        ),
        DocumentationItem(
            title: "Radial Gradient",
            description: "Create a radial gradient from center",
            syntax: nil,
            example: """
vec2 uv = v_texcoord - 0.5;
float dist = length(uv);
float gradient = 1.0 - smoothstep(0.0, 0.5, dist);
gl_FragColor = vec4(vec3(gradient), 1.0);
""",
            category: "gradient"
        )
    ]
}
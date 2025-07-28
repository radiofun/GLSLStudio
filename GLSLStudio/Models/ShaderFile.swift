import Foundation
import SwiftData

enum ShaderType: String, CaseIterable, Codable {
    case vertex = "vertex"
    case fragment = "fragment"
    
    var displayName: String {
        switch self {
        case .vertex: return "Vertex Shader"
        case .fragment: return "Fragment Shader"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .vertex: return ".vert"
        case .fragment: return ".frag"
        }
    }
}

@Model
final class ShaderFile {
    var id: UUID
    var name: String
    var type: ShaderType
    var content: String
    var lastModifiedDate: Date
    var thumbnailData: Data?
    
    var project: ShaderProject?
    
    init(name: String, type: ShaderType, content: String = "") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.content = content.isEmpty ? Self.defaultContent(for: type) : content
        self.lastModifiedDate = Date()
    }
    
    func updateContent(_ newContent: String) {
        content = newContent
        lastModifiedDate = Date()
        project?.updateModifiedDate()
    }
    
    static func defaultContent(for type: ShaderType) -> String {
        switch type {
        case .vertex:
            return defaultVertexShaderContent
        case .fragment:
            return defaultFragmentShaderContent
        }
    }
    
    static let defaultVertexShaderContent = """
attribute vec4 a_position;
attribute vec2 a_texcoord;

varying vec2 v_texcoord;

void main() {
    gl_Position = a_position;
    v_texcoord = a_texcoord;
}
"""
    
    static let defaultFragmentShaderContent = """
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
}
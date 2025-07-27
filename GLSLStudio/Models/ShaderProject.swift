import Foundation
import SwiftData

@Model
final class ShaderProject {
    var id: UUID
    var name: String
    var createdDate: Date
    var lastModifiedDate: Date
    var thumbnailData: Data?
    
    @Relationship(deleteRule: .cascade, inverse: \ShaderFile.project)
    var shaderFiles: [ShaderFile] = []
    
    var vertexShader: ShaderFile? {
        shaderFiles.first { $0.type == .vertex }
    }
    
    var fragmentShader: ShaderFile? {
        shaderFiles.first { $0.type == .fragment }
    }
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.lastModifiedDate = Date()
        
        let vertexShader = ShaderFile(
            name: "vertex",
            type: .vertex,
            content: ShaderFile.defaultVertexShaderContent
        )
        let fragmentShader = ShaderFile(
            name: "fragment", 
            type: .fragment,
            content: ShaderFile.defaultFragmentShaderContent
        )
        
        self.shaderFiles = [vertexShader, fragmentShader]
        vertexShader.project = self
        fragmentShader.project = self
    }
    
    func updateModifiedDate() {
        lastModifiedDate = Date()
    }
}
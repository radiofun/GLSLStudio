import Foundation
import SwiftData
import SwiftUI

@MainActor
class ProjectsViewModel: ObservableObject {
    private var modelContext: ModelContext?
    
    @Published var projects: [ShaderProject] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadProjects()
    }
    
    func loadProjects() {
        guard let context = modelContext else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<ShaderProject>(
                sortBy: [SortDescriptor(\.createdDate, order: .forward)]
            )
            projects = try context.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load projects: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createProject(name: String) -> ShaderProject {
        guard let context = modelContext else {
            fatalError("ModelContext not set")
        }
        
        let project = ShaderProject(name: name)
        context.insert(project)
        
        do {
            try context.save()
            loadProjects()
            return project
        } catch {
            errorMessage = "Failed to create project: \(error.localizedDescription)"
            return project
        }
    }
    
    func deleteProject(_ project: ShaderProject) {
        guard let context = modelContext else { return }
        
        context.delete(project)
        
        do {
            try context.save()
            loadProjects()
        } catch {
            errorMessage = "Failed to delete project: \(error.localizedDescription)"
        }
    }
    
    func duplicateProject(_ project: ShaderProject) -> ShaderProject {
        guard let context = modelContext else {
            fatalError("ModelContext not set")
        }
        
        let newProject = ShaderProject(name: "\(project.name) Copy")
        
        // Clear the default shader files that were created in init
        newProject.shaderFiles.removeAll()
        
        // Copy the actual shader files from the original project
        for shaderFile in project.shaderFiles {
            let newShaderFile = ShaderFile(
                name: shaderFile.name,
                type: shaderFile.type,
                content: shaderFile.content
            )
            newShaderFile.project = newProject
            newProject.shaderFiles.append(newShaderFile)
        }
        
        context.insert(newProject)
        
        do {
            try context.save()
            loadProjects()
            return newProject
        } catch {
            errorMessage = "Failed to duplicate project: \(error.localizedDescription)"
            return newProject
        }
    }
    
    func saveProject(_ project: ShaderProject) {
        guard let context = modelContext else { return }
        
        project.updateModifiedDate()
        
        do {
            try context.save()
            loadProjects()
        } catch {
            errorMessage = "Failed to save project: \(error.localizedDescription)"
        }
    }
    
    func updateShaderContent(_ shaderFile: ShaderFile, content: String) {
        shaderFile.updateContent(content)
        
        if let project = shaderFile.project {
            saveProject(project)
        }
    }
    
    func updateProjectThumbnail(_ project: ShaderProject, thumbnailData: Data) {
        print("💾 Updating thumbnail for project: \(project.name) (ID: \(project.id))")
        project.thumbnailData = thumbnailData
        saveProject(project)
        print("✅ Thumbnail updated and saved for project: \(project.name)")
    }
    
    func updateShaderFileThumbnail(_ shaderFile: ShaderFile, thumbnailData: Data) {
        shaderFile.thumbnailData = thumbnailData
        if let project = shaderFile.project {
            saveProject(project)
        }
    }
}
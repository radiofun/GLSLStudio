import SwiftUI

struct ProjectListView: View {
    @Binding var selectedProject: ShaderProject?
    @Binding var showNewProjectSheet: Bool
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var projectToDelete: ShaderProject?
    
    var filteredProjects: [ShaderProject] {
        if searchText.isEmpty {
            return projectsViewModel.projects
        } else {
            return projectsViewModel.projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ProjectListHeader(showNewProjectSheet: $showNewProjectSheet)
            
            if projectsViewModel.isLoading {
                ProgressView("Loading projects...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if projectsViewModel.projects.isEmpty {
                EmptyProjectsView(showNewProjectSheet: $showNewProjectSheet)
            } else {
                ProjectGrid(
                    projects: filteredProjects,
                    selectedProject: $selectedProject,
                    projectToDelete: $projectToDelete,
                    showingDeleteAlert: $showingDeleteAlert
                )
                .searchable(text: $searchText, prompt: "Search projects")
            }
        }
        .navigationTitle("GLSL Studio")
        .alert("Delete Project", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    projectsViewModel.deleteProject(project)
                    if selectedProject?.id == project.id {
                        selectedProject = nil
                    }
                }
                projectToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete '\(projectToDelete?.name ?? "")'? This action cannot be undone.")
        }
        .refreshable {
            projectsViewModel.loadProjects()
        }
    }
}

struct ProjectListHeader: View {
    @Binding var showNewProjectSheet: Bool
    
    var body: some View {
        HStack {
            Text("Projects")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: { showNewProjectSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ProjectGrid: View {
    let projects: [ShaderProject]
    @Binding var selectedProject: ShaderProject?
    @Binding var projectToDelete: ShaderProject?
    @Binding var showingDeleteAlert: Bool
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(projects, id: \.id) { project in
                    ProjectCard(
                        project: project,
                        isSelected: selectedProject?.id == project.id
                    ) {
                        selectedProject = project
                    }
                    .contextMenu {
                        ProjectContextMenu(
                            project: project,
                            projectToDelete: $projectToDelete,
                            showingDeleteAlert: $showingDeleteAlert
                        )
                    }
                }
            }
            .padding()
        }
    }
}

struct ProjectCard: View {
    let project: ShaderProject
    let isSelected: Bool
    let onTap: () -> Void
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: project.lastModifiedDate, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("Modified \(formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                }
            }
            
            ProjectThumbnail(project: project)
                .frame(height: 120)
                .cornerRadius(8)
            
            HStack {
                Text("\(project.shaderFiles.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(project.createdDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct ProjectThumbnail: View {
    let project: ShaderProject
    
    var body: some View {
        ZStack {
            if let thumbnailData = project.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [.blue.opacity(0.3), .orange.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack {
                    Image(systemName: "cube.transparent")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(Color(.systemGray6))
    }
}

struct ProjectContextMenu: View {
    let project: ShaderProject
    @Binding var projectToDelete: ShaderProject?
    @Binding var showingDeleteAlert: Bool
    @EnvironmentObject var projectsViewModel: ProjectsViewModel
    
    var body: some View {
        Button(action: {
            _ = projectsViewModel.duplicateProject(project)
        }) {
            Label("Duplicate", systemImage: "doc.on.doc")
        }
        
        Button(action: {
            // TODO: Implement rename
        }) {
            Label("Rename", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive, action: {
            projectToDelete = project
            showingDeleteAlert = true
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct EmptyProjectsView: View {
    @Binding var showNewProjectSheet: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Projects")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create your first GLSL shader project to get started")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showNewProjectSheet = true }) {
                Label("New Project", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
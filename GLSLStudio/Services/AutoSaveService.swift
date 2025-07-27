import Foundation
import Combine

class AutoSaveService: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var saveTimer: Timer?
    private let saveInterval: TimeInterval = 2.0 // Auto-save every 2 seconds
    
    weak var projectsViewModel: ProjectsViewModel?
    
    @Published var lastSaveTime: Date?
    @Published var hasUnsavedChanges = false
    
    init() {
        setupAutoSave()
    }
    
    func setProjectsViewModel(_ viewModel: ProjectsViewModel) {
        self.projectsViewModel = viewModel
    }
    
    private func setupAutoSave() {
        // Observe changes and trigger auto-save
        $hasUnsavedChanges
            .debounce(for: .seconds(saveInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] hasChanges in
                if hasChanges {
                    Task { @MainActor in
                        self?.performAutoSave()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func markAsChanged() {
        hasUnsavedChanges = true
    }
    
    @MainActor
    private func performAutoSave() {
        guard hasUnsavedChanges,
              let projectsViewModel = projectsViewModel else { return }
        
        // Save all projects that have unsaved changes
        // In a real implementation, you'd track which specific projects need saving
        for project in projectsViewModel.projects {
            projectsViewModel.saveProject(project)
        }
        
        hasUnsavedChanges = false
        lastSaveTime = Date()
    }
    
    func forceSave() {
        Task { @MainActor in
            performAutoSave()
        }
    }
    
    deinit {
        saveTimer?.invalidate()
        cancellables.removeAll()
    }
}

extension ProjectsViewModel {
    func connectAutoSave(_ autoSaveService: AutoSaveService) {
        autoSaveService.setProjectsViewModel(self)
    }
}
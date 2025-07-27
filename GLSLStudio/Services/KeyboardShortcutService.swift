import SwiftUI

struct KeyboardShortcutService {
    static func setupKeyboardShortcuts() -> some View {
        EmptyView()
            .keyboardShortcut("n", modifiers: [.command])
            .keyboardShortcut("s", modifiers: [.command])
            .keyboardShortcut("d", modifiers: [.command])
            .keyboardShortcut("r", modifiers: [.command])
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .keyboardShortcut("[", modifiers: [.command])
            .keyboardShortcut("]", modifiers: [.command])
    }
}

extension View {
    func glslStudioKeyboardShortcuts(
        projectsViewModel: ProjectsViewModel,
        selectedProject: Binding<ShaderProject?>,
        showNewProjectSheet: Binding<Bool>,
        showTemplateLibrary: Binding<Bool> = .constant(false)
    ) -> some View {
        self
            .keyboardShortcut("n", modifiers: [.command])
            .keyboardShortcut("s", modifiers: [.command])
            .keyboardShortcut("d", modifiers: [.command])
            .keyboardShortcut("r", modifiers: [.command])
    }
}
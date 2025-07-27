import Foundation
import Combine
import SwiftUI

class UndoRedoService: ObservableObject {
    private var undoStack: [ShaderVersion] = []
    private var redoStack: [ShaderVersion] = []
    private let maxHistorySize = 50
    
    @Published var canUndo = false
    @Published var canRedo = false
    
    func saveVersion(shaderFile: ShaderFile) {
        let version = ShaderVersion(
            fileId: shaderFile.id,
            content: shaderFile.content,
            timestamp: Date()
        )
        
        undoStack.append(version)
        redoStack.removeAll()
        
        // Limit stack size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        updateCanUndoRedo()
    }
    
    func undo(for shaderFile: ShaderFile) -> String? {
        // Find the most recent version for this file that's different from current
        for i in stride(from: undoStack.count - 1, through: 0, by: -1) {
            let version = undoStack[i]
            if version.fileId == shaderFile.id && version.content != shaderFile.content {
                // Move current state to redo stack
                let currentVersion = ShaderVersion(
                    fileId: shaderFile.id,
                    content: shaderFile.content,
                    timestamp: Date()
                )
                redoStack.append(currentVersion)
                
                // Remove versions up to and including this one
                let versionsToMove = Array(undoStack[i..<undoStack.count])
                undoStack.removeSubrange(i..<undoStack.count)
                
                updateCanUndoRedo()
                return version.content
            }
        }
        
        updateCanUndoRedo()
        return nil
    }
    
    func redo(for shaderFile: ShaderFile) -> String? {
        guard !redoStack.isEmpty else { return nil }
        
        let version = redoStack.removeLast()
        
        if version.fileId == shaderFile.id {
            // Move current state to undo stack
            let currentVersion = ShaderVersion(
                fileId: shaderFile.id,
                content: shaderFile.content,
                timestamp: Date()
            )
            undoStack.append(currentVersion)
            
            updateCanUndoRedo()
            return version.content
        }
        
        // Put it back if it wasn't for this file
        redoStack.append(version)
        updateCanUndoRedo()
        return nil
    }
    
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
    }
    
    func getVersionHistory(for shaderFile: ShaderFile) -> [ShaderVersion] {
        return undoStack.filter { $0.fileId == shaderFile.id }
    }
    
    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

struct ShaderVersion {
    let id = UUID()
    let fileId: UUID
    let content: String
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// Simple undo/redo UI components (implementation simplified)
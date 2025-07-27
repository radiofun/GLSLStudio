import SwiftUI

struct EmptyProjectView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.split.2x1")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Select a Project")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose a project from the sidebar to start editing shaders")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

class TextureService: ObservableObject {
    @Published var loadedTextures: [String: UIImage] = [:]
    
    func loadTexture(from item: PhotosPickerItem, completion: @escaping (String?, UIImage?) -> Void) {
        guard item.supportedContentTypes.contains(.image) else {
            completion(nil, nil)
            return
        }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        let textureId = UUID().uuidString
                        self.loadedTextures[textureId] = image
                        completion(textureId, image)
                    } else {
                        completion(nil, nil)
                    }
                case .failure(_):
                    completion(nil, nil)
                }
            }
        }
    }
    
    func removeTexture(id: String) {
        loadedTextures.removeValue(forKey: id)
    }
    
    func getTextureData(id: String) -> Data? {
        guard let image = loadedTextures[id] else { return nil }
        return image.pngData()
    }
}

struct TextureLoadingView: View {
    @StateObject private var textureService = TextureService()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingImagePicker = false
    
    let onTextureLoaded: (String, UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Textures")
                    .font(.headline)
                
                Spacer()
                
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 5,
                    matching: .images
                ) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                }
            }
            
            if textureService.loadedTextures.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No textures loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(textureService.loadedTextures.keys), id: \.self) { textureId in
                            if let image = textureService.loadedTextures[textureId] {
                                TextureCard(
                                    textureId: textureId,
                                    image: image,
                                    onRemove: {
                                        textureService.removeTexture(id: textureId)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onChange(of: selectedItems) { oldValue, newValue in
            for item in newValue {
                textureService.loadTexture(from: item) { textureId, image in
                    if let textureId = textureId, let image = image {
                        onTextureLoaded(textureId, image)
                    }
                }
            }
            selectedItems.removeAll()
        }
    }
}

struct TextureCard: View {
    let textureId: String
    let image: UIImage
    let onRemove: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .offset(x: 4, y: -4)
            }
            
            Text("texture_\(textureId.prefix(4))")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 80)
    }
}
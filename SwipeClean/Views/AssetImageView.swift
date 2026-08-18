import SwiftUI
import Photos

struct AssetImageView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    let item: CleanupAsset
    let targetSize: CGSize
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Rectangle().fill(Color.white.opacity(0.08)).overlay { ProgressView() } }
        }
        .task(id: item.id) {
            requestID = library.requestImage(for: item, targetSize: targetSize) { image = $0 }
        }
        .onDisappear { if let requestID { library.cancelImageRequest(requestID) } }
    }
}

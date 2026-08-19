import SwiftUI
import Photos

struct AssetImageView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    let item: CleanupAsset
    let targetSize: CGSize
    var contentMode: ContentMode = .fill
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode) }
            else { Rectangle().fill(Color.white.opacity(0.08)).overlay { ProgressView() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.id) {
            let photoContentMode: PHImageContentMode = contentMode == .fit ? .aspectFit : .aspectFill
            requestID = library.requestImage(for: item, targetSize: targetSize, contentMode: photoContentMode) { image = $0 }
        }
        .onDisappear { if let requestID { library.cancelImageRequest(requestID) } }
    }
}

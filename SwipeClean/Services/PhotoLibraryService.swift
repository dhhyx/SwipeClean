import Foundation
import Photos
import UIKit

@MainActor
final class PhotoLibraryService: ObservableObject {
    @Published private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var allAssets: [CleanupAsset] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let imageManager = PHCachingImageManager()
    private let decisionsKey = "SwipeClean.decisions.v1"
    @Published private var decisions: [String: CleanupDecision] = [:]

    init() {
        restoreDecisions()
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            Task { await reload() }
        }
    }

    func requestAuthorization() async {
        authorizationStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            await reload()
        }
    }

    func reload() async {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: options)
        var loaded: [CleanupAsset] = []
        loaded.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in loaded.append(CleanupAsset(asset: asset)) }
        allAssets = loaded
        isLoading = false
    }

    func assets(for mode: CleanupMode, limit: Int = 100) -> [CleanupAsset] {
        let calendar = Calendar.current
        let now = Date()
        let candidates: [CleanupAsset]
        switch mode {
        case .random:
            candidates = allAssets.shuffled()
        case .recent:
            candidates = allAssets
        case .screenshots:
            candidates = allAssets.filter { $0.asset.mediaSubtypes.contains(.photoScreenshot) }
        case .videos:
            candidates = allAssets.filter { $0.asset.mediaType == .video }
        case .similar:
            candidates = similarGroups().flatMap(\.assets)
        case .onThisDay:
            candidates = allAssets.filter {
                guard let date = $0.asset.creationDate else { return false }
                return !calendar.isDate(date, inSameDayAs: now)
                    && calendar.component(.month, from: date) == calendar.component(.month, from: now)
                    && calendar.component(.day, from: date) == calendar.component(.day, from: now)
            }
        }
        return Array(candidates.filter { decision(for: $0) == .undecided }.prefix(limit))
    }

    func similarGroups() -> [SimilarGroup] {
        let photos = allAssets.filter { $0.asset.mediaType == .image && $0.asset.creationDate != nil }
        var groups: [[CleanupAsset]] = []
        var current: [CleanupAsset] = []
        for item in photos {
            if let last = current.last,
               let lhs = last.asset.creationDate,
               let rhs = item.asset.creationDate,
               abs(lhs.timeIntervalSince(rhs)) <= 8,
               last.asset.pixelWidth == item.asset.pixelWidth,
               last.asset.pixelHeight == item.asset.pixelHeight {
                current.append(item)
            } else {
                if current.count > 1 { groups.append(current) }
                current = [item]
            }
        }
        if current.count > 1 { groups.append(current) }
        return groups.map { SimilarGroup(assets: $0) }
    }

    func requestImage(
        for item: CleanupAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return imageManager.requestImage(for: item.asset, targetSize: targetSize, contentMode: contentMode, options: options) { image, _ in
            DispatchQueue.main.async { completion(image) }
        }
    }

    func cancelImageRequest(_ id: PHImageRequestID) { imageManager.cancelImageRequest(id) }

    func decision(for item: CleanupAsset) -> CleanupDecision { decisions[item.id] ?? .undecided }

    func setDecision(_ decision: CleanupDecision, for item: CleanupAsset) async {
        updateDecision(decision, forID: item.id)
        if decision == .favorite || decision == .keep {
            await setFavorite(decision == .favorite, for: item.asset)
        }
    }

    func undoDecision(for item: CleanupAsset) {
        updateDecision(nil, forID: item.id)
    }

    var queuedForDeletion: [CleanupAsset] {
        allAssets.filter { decisions[$0.id] == .delete }
    }

    func commitDeletion() async throws {
        let queuedItems = queuedForDeletion
        let assets = queuedItems.map(\.asset) as NSArray
        guard assets.count > 0 else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
        let removedIDs = Set(queuedItems.map(\.id))
        decisions = decisions.filter { !removedIDs.contains($0.key) }
        persistDecisions()
        await reload()
    }

    func clearDeletionQueue() {
        let removedIDs = Set(queuedForDeletion.map(\.id))
        decisions = decisions.filter { !removedIDs.contains($0.key) }
        persistDecisions()
    }

    private func updateDecision(_ decision: CleanupDecision?, forID id: String) {
        var updated = decisions
        if let decision {
            updated[id] = decision
        } else {
            updated.removeValue(forKey: id)
        }
        decisions = updated
        persistDecisions()
    }

    private func setFavorite(_ favorite: Bool, for asset: PHAsset) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest(for: asset).isFavorite = favorite
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func restoreDecisions() {
        guard let data = UserDefaults.standard.data(forKey: decisionsKey),
              let saved = try? JSONDecoder().decode([String: CleanupDecision].self, from: data) else { return }
        decisions = saved
    }

    private func persistDecisions() {
        guard let data = try? JSONEncoder().encode(decisions) else { return }
        UserDefaults.standard.set(data, forKey: decisionsKey)
    }
}

import Foundation

@MainActor
final class CleanupSessionViewModel: ObservableObject {
    @Published private(set) var items: [CleanupAsset]
    @Published private(set) var index = 0
    @Published private(set) var history: [(CleanupAsset, CleanupDecision)] = []
    @Published private(set) var summary = CleanupSummary()

    init(items: [CleanupAsset]) { self.items = items }

    var current: CleanupAsset? { index < items.count ? items[index] : nil }
    var next: CleanupAsset? { index + 1 < items.count ? items[index + 1] : nil }
    var progress: Double { items.isEmpty ? 0 : Double(index) / Double(items.count) }

    func decide(_ decision: CleanupDecision, using library: PhotoLibraryService) async {
        guard let item = current else { return }
        history.append((item, decision))
        summary.reviewed += 1
        switch decision {
        case .keep: summary.kept += 1
        case .delete: summary.queuedForDeletion += 1
        case .favorite: summary.favorites += 1
        case .undecided: break
        }
        await library.setDecision(decision, for: item)
        index += 1
    }

    func undo(using library: PhotoLibraryService) {
        guard let last = history.popLast(), index > 0 else { return }
        index -= 1
        library.undoDecision(for: last.0)
        summary.reviewed = max(0, summary.reviewed - 1)
        switch last.1 {
        case .keep: summary.kept = max(0, summary.kept - 1)
        case .delete: summary.queuedForDeletion = max(0, summary.queuedForDeletion - 1)
        case .favorite: summary.favorites = max(0, summary.favorites - 1)
        case .undecided: break
        }
    }
}

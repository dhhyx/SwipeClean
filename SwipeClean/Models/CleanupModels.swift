import Foundation
import Photos

enum CleanupDecision: String, Codable {
    case undecided
    case keep
    case delete
    case favorite
}

enum CleanupMode: String, CaseIterable, Identifiable {
    case random = "随机回忆"
    case recent = "最近照片"
    case screenshots = "截图"
    case videos = "视频"
    case similar = "相似照片"
    case onThisDay = "往年今日"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .random: return "shuffle"
        case .recent: return "clock"
        case .screenshots: return "rectangle.dashed"
        case .videos: return "play.rectangle.fill"
        case .similar: return "square.on.square"
        case .onThisDay: return "calendar"
        }
    }

    var tint: String {
        switch self {
        case .random: return "7C5CFC"
        case .recent: return "2D9CDB"
        case .screenshots: return "F2994A"
        case .videos: return "EB5757"
        case .similar: return "27AE60"
        case .onThisDay: return "BB6BD9"
        }
    }
}

struct CleanupAsset: Identifiable, Hashable {
    let asset: PHAsset
    var id: String { asset.localIdentifier }

    static func == (lhs: CleanupAsset, rhs: CleanupAsset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SimilarGroup: Identifiable {
    let id = UUID()
    let assets: [CleanupAsset]
}

struct CleanupSummary {
    var reviewed = 0
    var kept = 0
    var queuedForDeletion = 0
    var favorites = 0
}

import SwiftUI
import Photos

struct RootView: View {
    @EnvironmentObject private var library: PhotoLibraryService

    var body: some View {
        Group {
            switch library.authorizationStatus {
            case .authorized, .limited:
                DashboardView()
            case .notDetermined:
                PermissionView()
            default:
                PermissionDeniedView()
            }
        }
        .background(Color(hex: "090A0E").ignoresSafeArea())
        .alert("出现问题", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct PermissionView: View {
    @EnvironmentObject private var library: PhotoLibraryService

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.stack.fill").font(.system(size: 72)).foregroundStyle(.purple, .blue)
            Text("整理相册，从一次滑动开始").font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("SwipeClean 只在你的设备上处理照片。删除前会先进入待确认列表。")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 36)
            Button { Task { await library.requestAuthorization() } } label: {
                Text("允许访问照片").font(.headline).frame(maxWidth: .infinity).padding()
            }
            .buttonStyle(.borderedProminent).tint(Color(hex: "7C5CFC")).padding(.horizontal, 28)
            Spacer()
        }
    }
}

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.badge.exclamationmark").font(.system(size: 58)).foregroundStyle(.orange)
            Text("需要照片权限").font(.title.bold())
            Text("请前往“设置 → 隐私与安全性 → 照片 → SwipeClean”，允许访问照片。")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 30)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.buttonStyle(.borderedProminent)
        }
    }
}

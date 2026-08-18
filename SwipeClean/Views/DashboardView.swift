import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    @State private var selectedMode: CleanupMode?
    @State private var showingReview = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    Text("选择一种清理方式").font(.title3.bold())
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(CleanupMode.allCases) { mode in
                            ModeTile(mode: mode, count: library.assets(for: mode, limit: 10_000).count)
                                .onTapGesture { selectedMode = mode }
                        }
                    }
                    if !library.queuedForDeletion.isEmpty {
                        Button { showingReview = true } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("检查待删除项目")
                                Spacer()
                                Text("\(library.queuedForDeletion.count)").font(.headline.monospacedDigit())
                            }
                            .padding().background(Color.red.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain)
                    }
                    privacyNote
                }.padding(18)
            }
            .navigationTitle("SwipeClean")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await library.reload() } } label: { Image(systemName: "arrow.clockwise") }
                }
            }
            .overlay { if library.isLoading { ProgressView("正在读取照片…").padding(22).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18)) } }
            .sheet(item: $selectedMode) { mode in
                SwipeDeckView(mode: mode, items: library.assets(for: mode))
            }
            .sheet(isPresented: $showingReview) { ReviewDeleteView() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("你的照片库").font(.headline); Spacer(); Image(systemName: "sparkles").foregroundStyle(.yellow) }
            Text("\(library.allAssets.count.formatted())").font(.system(size: 44, weight: .bold, design: .rounded))
            Text("张照片与视频可整理").foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Color(hex: "241A4B"), Color(hex: "101A32")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
    }

    private var privacyNote: some View {
        Label("所有分析都在设备本地完成。照片不会上传到服务器。", systemImage: "lock.shield.fill")
            .font(.footnote).foregroundStyle(.secondary).padding(.vertical, 8)
    }
}

private struct ModeTile: View {
    let mode: CleanupMode
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: mode.icon).font(.title2).foregroundStyle(.white).padding(10).background(Color.white.opacity(0.16), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.rawValue).font(.headline)
                Text("\(count.formatted()) 项").font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        }.padding(16).frame(maxWidth: .infinity, minHeight: 138, alignment: .leading)
            .background(Color(hex: mode.tint).gradient, in: RoundedRectangle(cornerRadius: 20))
    }
}

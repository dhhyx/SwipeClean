import SwiftUI

struct SwipeDeckView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    let mode: CleanupMode
    @StateObject private var session: CleanupSessionViewModel
    @State private var showingReview = false

    init(mode: CleanupMode, items: [CleanupAsset]) {
        self.mode = mode
        _session = StateObject(wrappedValue: CleanupSessionViewModel(items: items))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView(value: session.progress).tint(Color(hex: mode.tint)).padding(.horizontal)
                HStack { Text("\(session.index + min(1, session.items.count))/\(session.items.count)").monospacedDigit(); Spacer(); Text("上滑删除 · 下滑收藏").foregroundStyle(.secondary) }.font(.caption).padding(.horizontal)
                GeometryReader { proxy in
                    let cardAspectRatio = displayedAspectRatio(for: session.current)
                    let cardWidth = min(proxy.size.width, proxy.size.height * cardAspectRatio)
                    let cardHeight = cardWidth / cardAspectRatio

                    ZStack {
                        if let next = session.next {
                            PhotoCardView(item: next, enabled: false)
                                .scaleEffect(0.95)
                                .opacity(0.55)
                                .offset(y: 10)
                        }
                        if let current = session.current {
                            PhotoCardView(item: current, enabled: true) { decision in
                                Task { await session.decide(decision, using: library) }
                            }
                            .id(current.id)
                        } else {
                            completion
                        }
                    }
                    .frame(width: cardWidth, height: cardHeight)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
                actionBar
            }
            .background(Color(hex: "090A0E").ignoresSafeArea())
            .navigationTitle(mode.rawValue).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } } }
            .sheet(isPresented: $showingReview) { ReviewDeleteView() }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 24) {
            circleButton("arrow.uturn.backward", .gray) { session.undo(using: library) }
            circleButton("trash.fill", .red) { Task { await session.decide(.delete, using: library) } }
            circleButton("heart.fill", .pink) { Task { await session.decide(.favorite, using: library) } }
            circleButton("checkmark", .green) { Task { await session.decide(.keep, using: library) } }
        }.padding(.bottom, 14)
    }

    private func circleButton(_ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title2.bold()).frame(width: 54, height: 54).background(color.opacity(0.2), in: Circle()).foregroundStyle(color) }
    }

    private var completion: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text("这一批整理完成").font(.title.bold())
            Text("已查看 \(session.summary.reviewed) 项，待删除队列现有 \(library.queuedForDeletion.count) 项。")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            if !library.queuedForDeletion.isEmpty {
                Button("检查待删除项目") { showingReview = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }.padding(30)
    }

    private func displayedAspectRatio(for item: CleanupAsset?) -> CGFloat {
        guard let asset = item?.asset, asset.pixelWidth > 0, asset.pixelHeight > 0 else { return 0.8 }
        let originalRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        return min(max(originalRatio, 0.42), 2.2)
    }
}

import SwiftUI

struct ReviewDeleteView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var deleting = false
    @State private var showingConfirmation = false
    @State private var deletionError: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 3)]

    var body: some View {
        NavigationStack {
            Group {
                if library.queuedForDeletion.isEmpty {
                    ContentUnavailableView("没有待删除项目", systemImage: "trash", description: Text("滑动标记的照片会先出现在这里。"))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(library.queuedForDeletion) { item in
                                ZStack(alignment: .topTrailing) {
                                    AssetImageView(item: item, targetSize: CGSize(width: 240, height: 240)).frame(height: 112).clipped()
                                    Button { library.undoDecision(for: item) } label: {
                                        Image(systemName: "xmark.circle.fill").font(.title2).symbolRenderingMode(.palette).foregroundStyle(.white, .black.opacity(0.65)).padding(5)
                                    }
                                }
                            }
                        }.padding(3)
                    }
                }
            }
            .navigationTitle("删除前确认").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("删除 \(library.queuedForDeletion.count) 项", role: .destructive) { showingConfirmation = true }
                        .disabled(library.queuedForDeletion.isEmpty || deleting)
                }
            }
            .confirmationDialog("确定从照片图库删除这些项目吗？", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("删除 \(library.queuedForDeletion.count) 项", role: .destructive) {
                    deleting = true
                    Task {
                        do { try await library.commitDeletion(); dismiss() }
                        catch { deletionError = error.localizedDescription; deleting = false }
                    }
                }
                Button("取消", role: .cancel) {}
            } message: { Text("iOS 仍会显示系统确认。删除的项目通常可以在“最近删除”中恢复。") }
            .alert("删除失败", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
                Button("好") { deletionError = nil }
            } message: { Text(deletionError ?? "") }
            .overlay { if deleting { ProgressView("正在删除…").padding(22).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
        }
    }
}

import SwiftUI

struct PhotoCardView: View {
    let item: CleanupAsset
    let enabled: Bool
    var onDecision: (CleanupDecision) -> Void = { _ in }

    @State private var offset: CGSize = .zero
    @State private var rotation = 0.0

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                AssetImageView(
                    item: item,
                    targetSize: CGSize(width: proxy.size.width * 2, height: proxy.size.height * 2),
                    contentMode: .fit
                )
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                decisionOverlay
                VStack { Spacer(); metadata.padding(18) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .contentShape(Rectangle())
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .gesture(enabled ? dragGesture(size: proxy.size) : nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: offset)
        }
    }

    private var metadata: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = item.asset.creationDate {
                    Text(date, format: .dateTime.year().month().day()).font(.headline)
                    Text(date, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.asset.mediaType == .video {
                Label(durationText, systemImage: "play.fill").font(.caption.bold()).padding(7).background(.black.opacity(0.55), in: Capsule())
            }
        }
    }

    @ViewBuilder private var decisionOverlay: some View {
        let horizontal = offset.width
        let vertical = offset.height
        if abs(horizontal) > abs(vertical), abs(horizontal) > 35 {
            stamp(horizontal > 0 ? "保留" : "删除", icon: horizontal > 0 ? "checkmark" : "trash.fill", color: horizontal > 0 ? .green : .red)
                .opacity(Double(min(abs(horizontal) / CGFloat(120), CGFloat(1))))
        } else if abs(vertical) > 35 {
            stamp(vertical < 0 ? "删除" : "收藏", icon: vertical < 0 ? "trash.fill" : "heart.fill", color: vertical < 0 ? .red : .pink)
                .opacity(Double(min(abs(vertical) / CGFloat(120), CGFloat(1))))
        }
    }

    private func stamp(_ text: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) { Image(systemName: icon).font(.system(size: 46, weight: .black)); Text(text).font(.largeTitle.weight(.black)) }
            .foregroundStyle(color).padding(22).background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 20)).rotationEffect(.degrees(-8))
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in offset = value.translation; rotation = Double(value.translation.width / max(size.width, 1)) * 8 }
            .onEnded { value in
                let x = value.translation.width, y = value.translation.height
                let threshold = min(size.width, size.height) * 0.22
                guard max(abs(x), abs(y)) > threshold else { offset = .zero; rotation = 0; return }
                let decision: CleanupDecision
                if abs(x) > abs(y) { decision = x > 0 ? .keep : .delete }
                else { decision = y < 0 ? .delete : .favorite }
                offset = CGSize(width: x.sign == .minus ? -size.width * 1.4 : size.width * 1.4, height: y)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onDecision(decision); offset = .zero; rotation = 0 }
            }
    }

    private var durationText: String {
        let seconds = Int(item.asset.duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

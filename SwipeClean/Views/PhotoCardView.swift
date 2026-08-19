import AVKit
import Photos
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
                media(targetSize: CGSize(width: proxy.size.width * 2, height: proxy.size.height * 2))
                LinearGradient(colors: [.clear, .black.opacity(0.72)], startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
                decisionOverlay
                    .allowsHitTesting(false)
                VStack { Spacer(); metadata.padding(18) }
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .contentShape(Rectangle())
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .gesture(enabled ? dragGesture(size: proxy.size) : nil)
            .animation(.spring(response: 0.35, dampingFraction: 0.78), value: offset)
        }
    }

    @ViewBuilder
    private func media(targetSize: CGSize) -> some View {
        if item.asset.mediaType == .video && enabled {
            AssetVideoView(item: item, targetSize: targetSize)
        } else {
            AssetImageView(item: item, targetSize: targetSize, contentMode: .fit)
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
        DragGesture(minimumDistance: 18)
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
}

private struct AssetVideoView: View {
    @EnvironmentObject private var library: PhotoLibraryService
    let item: CleanupAsset
    let targetSize: CGSize
    @StateObject private var model = AssetVideoPlayerModel()

    var body: some View {
        ZStack {
            AssetImageView(item: item, targetSize: targetSize, contentMode: .fit)

            if model.isReady {
                VideoPlayer(player: model.player)
                    .allowsHitTesting(false)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if model.isReady && !model.isPlaying {
                Button(action: model.togglePlayback) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 66, height: 66)
                        .background(.black.opacity(0.62), in: Circle())
                }
                .accessibilityLabel("播放视频")
            }

            VStack {
                Spacer()
                videoControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 68)
            }
        }
        .onAppear { model.load(item, using: library) }
        .onDisappear { model.unload(using: library) }
    }

    private var videoControls: some View {
        HStack(spacing: 10) {
            Button(action: model.togglePlayback) {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.caption.bold())
                    .frame(width: 28, height: 28)
            }
            .disabled(!model.isReady)
            .accessibilityLabel(model.isPlaying ? "暂停视频" : "播放视频")

            Slider(
                value: Binding(
                    get: { model.currentTime },
                    set: { model.setPendingTime($0) }
                ),
                in: 0...model.maximumDuration,
                onEditingChanged: model.setScrubbing
            )
            .tint(.white)
            .disabled(!model.isReady)

            Text("\(timeText(model.currentTime)) / \(timeText(model.duration))")
                .font(.caption2.monospacedDigit())
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.66), in: Capsule())
    }

    private func timeText(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let seconds = Int(value.rounded(.down))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

@MainActor
private final class AssetVideoPlayerModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isReady = false
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: Double = 0
    @Published var currentTime: Double = 0

    private var requestID: PHImageRequestID?
    private var timeObserver: Any?
    private var loadedAssetID: String?
    private var wasPlayingBeforeScrubbing = false
    private var isScrubbing = false

    var maximumDuration: Double { max(duration, 0.1) }

    func load(_ item: CleanupAsset, using library: PhotoLibraryService) {
        guard loadedAssetID != item.id || player.currentItem == nil else { return }
        unload(using: library)
        loadedAssetID = item.id
        duration = max(item.asset.duration, 0)
        let requestedAssetID = item.id
        requestID = library.requestPlayerItem(for: item) { [weak self] playerItem in
            guard let self else { return }
            self.finishLoading(playerItem, assetID: requestedAssetID)
        }
    }

    func unload(using library: PhotoLibraryService) {
        if let requestID {
            library.cancelImageRequest(requestID)
            self.requestID = nil
        }
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
        loadedAssetID = nil
        isReady = false
        isPlaying = false
        currentTime = 0
    }

    func togglePlayback() {
        guard isReady else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            if duration > 0, currentTime >= duration - 0.15 {
                player.seek(to: .zero)
                currentTime = 0
            }
            player.play()
            isPlaying = true
        }
    }

    func setPendingTime(_ time: Double) {
        currentTime = min(max(time, 0), maximumDuration)
    }

    func setScrubbing(_ editing: Bool) {
        guard isReady else { return }
        if editing {
            isScrubbing = true
            wasPlayingBeforeScrubbing = isPlaying
            player.pause()
            isPlaying = false
        } else {
            let target = CMTime(seconds: currentTime, preferredTimescale: 600)
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
            isScrubbing = false
            if wasPlayingBeforeScrubbing {
                player.play()
                isPlaying = true
            }
        }
    }

    private func finishLoading(_ playerItem: AVPlayerItem?, assetID: String) {
        guard loadedAssetID == assetID, let playerItem else { return }
        requestID = nil
        player.replaceCurrentItem(with: playerItem)
        let itemDuration = playerItem.asset.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }
        isReady = true
        installTimeObserver()
    }

    private func installTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in self?.updatePlaybackState(time: time) }
        }
    }

    private func updatePlaybackState(time: CMTime) {
        let seconds = time.seconds
        if !isScrubbing, seconds.isFinite { currentTime = min(max(seconds, 0), maximumDuration) }
        let itemDuration = player.currentItem?.duration.seconds ?? 0
        if itemDuration.isFinite, itemDuration > 0 { duration = itemDuration }
        isPlaying = player.timeControlStatus == .playing
    }
}

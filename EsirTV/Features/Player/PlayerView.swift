//
//  PlayerView.swift
//  EsirTV
//

import AVKit
import SwiftUI

/// 播放界面（关闭时彻底停止音频）
struct PlayerView: View {
    let title: String
    let episodeTitle: String?
    let streamURL: URL?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerHolder = PlayerHolder()
    @State private var showCastPicker = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playerHolder.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                placeholder
            }

            VStack {
                HStack {
                    Button {
                        stopAndDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                    Spacer()
                    if streamURL != nil {
                        Button {
                            showCastPicker = true
                        } label: {
                            Image(systemName: "airplayvideo")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            if let streamURL {
                playerHolder.start(url: streamURL)
            }
        }
        .onDisappear {
            playerHolder.stop()
        }
        .sheet(isPresented: $showCastPicker) {
            if let streamURL {
                CastDevicePickerView(
                    mediaURL: streamURL,
                    title: episodeTitle.map { "\(title) · \($0)" } ?? title
                )
            }
        }
    }

    private func stopAndDismiss() {
        playerHolder.stop()
        dismiss()
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.8))
            Text("暂无播放地址")
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

// MARK: - 播放器生命周期

private final class PlayerHolder: ObservableObject {
    @Published private(set) var player: AVPlayer?

    func start(url: URL) {
        stop()
        let newPlayer = AVPlayer(url: url)
        newPlayer.play()
        player = newPlayer
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    deinit {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
}

#Preview {
    PlayerView(title: "测试", episodeTitle: nil, streamURL: nil)
}

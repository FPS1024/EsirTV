//
//  PlayerView.swift
//  EsirTV
//

import AVKit
import SwiftUI

/// 播放界面（支持 URL 播放，无地址时显示占位）
struct PlayerView: View {
    let title: String
    let episodeTitle: String?
    let streamURL: URL?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let streamURL {
                VideoPlayer(player: AVPlayer(url: streamURL))
                    .ignoresSafeArea()
            } else {
                placeholder
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "play.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.8))
            Text("暂无播放地址")
                .foregroundColor(.white.opacity(0.9))
            Text("接入影视源后可在此播放")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    PlayerView(title: "测试", episodeTitle: nil, streamURL: nil)
}

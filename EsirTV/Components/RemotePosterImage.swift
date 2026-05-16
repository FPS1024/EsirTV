//
//  RemotePosterImage.swift
//  EsirTV
//

import SwiftUI

/// 远程海报（带 Referer，等同后端图片代理效果）
struct RemotePosterImage: View {
    let urlString: String
    var fallbackSystemImage: String = "film"

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                placeholder
            } else {
                placeholder
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            }
        }
        .clipped()
        .task(id: urlString) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.tertiarySystemFill)
            Image(systemName: fallbackSystemImage)
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }

    private func loadImage() async {
        image = nil
        failed = false
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            failed = true
            return
        }
        do {
            let data = try await TVBoxHTTPClient.fetchImageData(urlString: trimmed)
            if let uiImage = UIImage(data: data) {
                image = uiImage
            } else {
                failed = true
            }
        } catch {
            failed = true
        }
    }
}

//
//  MediaPosterView.swift
//  EsirTV
//

import SwiftUI

/// 影视海报卡片（一行三列网格复用）
struct MediaPosterView: View {
    let item: VodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemotePosterImage(urlString: item.posterURL)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .foregroundColor(.primary)

            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    MediaPosterView(
        item: VodItem(
            siteKey: "demo",
            vodId: "1",
            title: "示例影片",
            posterURL: "",
            typeName: "电影",
            vodYear: "2024"
        )
    )
    .frame(width: 110)
    .padding()
}

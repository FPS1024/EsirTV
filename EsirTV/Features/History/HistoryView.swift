//
//  HistoryView.swift
//  EsirTV
//

import SwiftUI

struct HistoryView: View {
    // 预留：对接播放历史持久化（与 server.js /api/history 同结构）
    @State private var items: [VodItem] = []

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    EmptyStateView(
                        systemImage: "clock",
                        title: "暂无历史记录",
                        message: "开始观看后，进度会保存在这里"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(items) { item in
                                NavigationLink {
                                    MediaDetailView(listItem: item)
                                } label: {
                                    MediaPosterView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("历史记录")
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(ConfigStore())
        .environmentObject(FavoritesStore())
}

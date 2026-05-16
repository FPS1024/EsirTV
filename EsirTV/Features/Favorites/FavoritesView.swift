//
//  FavoritesView.swift
//  EsirTV
//

import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var configStore: ConfigStore

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if favoritesStore.items.isEmpty {
                    EmptyStateView(
                        systemImage: "heart",
                        title: "暂无收藏",
                        message: "在详情页点击收藏，喜欢的影片会显示在这里"
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 14) {
                            ForEach(favoritesStore.items) { item in
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
            .navigationTitle("收藏")
        }
    }
}

#Preview {
    FavoritesView()
        .environmentObject(FavoritesStore())
        .environmentObject(ConfigStore())
}

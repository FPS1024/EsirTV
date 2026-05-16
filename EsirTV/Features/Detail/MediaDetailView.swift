//
//  MediaDetailView.swift
//  EsirTV
//

import SwiftUI

struct MediaDetailView: View {
    @StateObject private var viewModel: MediaDetailViewModel
    @EnvironmentObject private var configStore: ConfigStore
    @EnvironmentObject private var favoritesStore: FavoritesStore

    init(listItem: VodItem) {
        _viewModel = StateObject(wrappedValue: MediaDetailViewModel(listItem: listItem))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                playerSection
                synopsisSection
                if !viewModel.playSources.isEmpty {
                    sourceSection
                }
                if !viewModel.episodes.isEmpty {
                    episodesSection
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(viewModel.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                favoriteButton
            }
        }
        .task {
            await viewModel.loadDetail(configStore: configStore)
        }
        .fullScreenCover(isPresented: $viewModel.showPlayer) {
            NavigationStack {
                PlayerView(
                    title: viewModel.displayTitle,
                    episodeTitle: viewModel.selectedEpisode?.displayTitle,
                    streamURL: viewModel.playURL
                )
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            RemotePosterImage(urlString: viewModel.displayPoster)
                .frame(width: 120, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.displayTitle)
                    .font(.title2.bold())

                if let subtitle = viewModel.displaySubtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if viewModel.isLoading {
                    ProgressView()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer(minLength: 0)

                favoriteButton
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var playerSection: some View {
        Button {
            viewModel.play()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .aspectRatio(16 / 9, contentMode: .fit)

                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white)

                    if let episode = viewModel.selectedEpisode {
                        Text(episode.displayTitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    } else {
                        Text("立即播放")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)

            Text(viewModel.displaySynopsis.isEmpty ? "暂无简介" : viewModel.displaySynopsis)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("播放源")
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(viewModel.playSources.enumerated()), id: \.element.id) { index, source in
                        Button {
                            viewModel.selectSource(at: index)
                        } label: {
                            Text(source.name)
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedSourceIndex == index
                                        ? Color.accentColor
                                        : Color(.tertiarySystemFill)
                                )
                                .foregroundColor(
                                    viewModel.selectedSourceIndex == index ? .white : .primary
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选集")
                    .font(.headline)
                Spacer()
                if let selected = viewModel.selectedEpisode {
                    Text(selected.displayTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.episodes) { episode in
                        EpisodeChip(
                            episode: episode,
                            isSelected: viewModel.selectedEpisode?.id == episode.id
                        ) {
                            viewModel.selectEpisode(episode)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var favoriteButton: some View {
        Button {
            favoritesStore.toggle(viewModel.listItem)
        } label: {
            Label(
                favoritesStore.isFavorite(viewModel.listItem) ? "已收藏" : "收藏",
                systemImage: favoritesStore.isFavorite(viewModel.listItem) ? "heart.fill" : "heart"
            )
            .foregroundColor(favoritesStore.isFavorite(viewModel.listItem) ? .red : .primary)
        }
    }
}

private struct EpisodeChip: View {
    let episode: PlayEpisode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(episode.displayTitle)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(
            listItem: VodItem(
                siteKey: "demo",
                vodId: "1",
                title: "示例",
                posterURL: ""
            )
        )
    }
    .environmentObject(ConfigStore())
    .environmentObject(FavoritesStore())
}

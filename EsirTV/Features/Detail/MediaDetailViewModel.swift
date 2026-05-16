//
//  MediaDetailViewModel.swift
//  EsirTV
//

import Combine
import Foundation

@MainActor
final class MediaDetailViewModel: ObservableObject {
    let listItem: VodItem

    @Published var detail: VodDetail?
    @Published var selectedSourceIndex = 0
    @Published var selectedEpisode: PlayEpisode?
    @Published var showPlayer = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    var playSources: [PlaySource] {
        detail?.playSources ?? []
    }

    var currentSource: PlaySource? {
        guard playSources.indices.contains(selectedSourceIndex) else { return playSources.first }
        return playSources[selectedSourceIndex]
    }

    var episodes: [PlayEpisode] {
        currentSource?.episodes ?? []
    }

    var playURL: URL? {
        guard let urlString = selectedEpisode?.playURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    var displayTitle: String { detail?.title ?? listItem.title }
    var displayPoster: String { detail?.posterURL ?? listItem.posterURL }
    var displaySynopsis: String { detail?.synopsis ?? "" }
    var displaySubtitle: String? { detail?.listItem.subtitle ?? listItem.subtitle }

    init(listItem: VodItem) {
        self.listItem = listItem
    }

    func loadDetail(configStore: ConfigStore) async {
        guard let site = configStore.sites.first(where: { $0.id == listItem.siteKey }) else {
            errorMessage = "站点不存在"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await TVBoxAPIService.fetchDetail(
                apiURL: site.api,
                siteKey: listItem.siteKey,
                vodId: listItem.vodId
            )
            detail = loaded
            selectedSourceIndex = 0
            selectedEpisode = loaded.playSources.first?.episodes.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSource(at index: Int) {
        guard playSources.indices.contains(index) else { return }
        selectedSourceIndex = index
        selectedEpisode = playSources[index].episodes.first
    }

    func selectEpisode(_ episode: PlayEpisode) {
        selectedEpisode = episode
    }

    func play() {
        showPlayer = true
    }
}

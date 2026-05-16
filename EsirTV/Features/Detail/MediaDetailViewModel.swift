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

    private var loadTask: Task<Void, Never>?

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
        if let cached = VodDetailCache.shared.detail(for: listItem) {
            applyDetail(cached)
        }
    }

    func loadDetail(configStore: ConfigStore) async {
        if detail != nil, VodDetailCache.shared.detail(for: listItem) != nil {
            return
        }

        loadTask?.cancel()
        loadTask = Task {
            await fetchDetail(configStore: configStore)
        }
        await loadTask?.value
    }

    private func fetchDetail(configStore: ConfigStore) async {
        guard let site = configStore.sites.first(where: { $0.id == listItem.siteKey }) else {
            errorMessage = "站点不存在"
            return
        }

        isLoading = detail == nil
        errorMessage = nil
        defer { isLoading = false }

        do {
            try Task.checkCancellation()
            let loaded = try await TVBoxAPIService.fetchDetail(
                apiURL: site.api,
                siteKey: listItem.siteKey,
                vodId: listItem.vodId
            )
            guard !Task.isCancelled else { return }
            applyDetail(loaded)
            VodDetailCache.shared.save(loaded)
        } catch is CancellationError {
            return
        } catch {
            if detail == nil {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func applyDetail(_ loaded: VodDetail) {
        detail = loaded
        selectedSourceIndex = 0
        selectedEpisode = loaded.playSources.first?.episodes.first
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

    func stopPlayer() {
        showPlayer = false
    }
}

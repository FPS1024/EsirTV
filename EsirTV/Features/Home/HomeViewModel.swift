//
//  HomeViewModel.swift
//  EsirTV
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var categories: [VodCategory] = []
    @Published var selectedTypeId: Int = 0
    @Published var vodItems: [VodItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var showSearchBar = false
    @Published var scrollAnchorToRestore: String?

    private var currentPage = 1
    private var hasMore = true
    private var loadGeneration = 0
    private var activeLoadTask: Task<Void, Never>?
    private var categoryDebounceTask: Task<Void, Never>?

    func cacheKey(siteKey: String) -> HomeFeedCacheKey {
        HomeFeedCacheKey(
            siteKey: siteKey,
            typeId: selectedTypeId,
            searchQuery: isSearching ? searchText : ""
        )
    }

    func bootstrap(configStore: ConfigStore) async {
        await configStore.loadSites(force: false)
        guard let site = configStore.selectedSite else { return }
        await loadCategories(apiURL: site.api)
        if restoreFromCache(siteKey: site.id) {
            return
        }
        await reloadList(configStore: configStore, forceNetwork: true)
    }

    func restoreFromCache(siteKey: String) -> Bool {
        guard let cached = HomeFeedCache.shared.state(for: cacheKey(siteKey: siteKey)) else {
            return false
        }
        vodItems = cached.items
        currentPage = cached.currentPage
        hasMore = cached.hasMore
        errorMessage = nil
        scrollAnchorToRestore = cached.scrollAnchorId
        return !cached.items.isEmpty
    }

    func saveCache(siteKey: String, scrollAnchorId: String? = nil) {
        let anchor = scrollAnchorId ?? scrollAnchorToRestore
        HomeFeedCache.shared.save(
            key: cacheKey(siteKey: siteKey),
            items: vodItems,
            currentPage: currentPage,
            hasMore: hasMore,
            scrollAnchorId: anchor
        )
    }

    func markScrollAnchor(_ itemId: String, siteKey: String) {
        scrollAnchorToRestore = itemId
        HomeFeedCache.shared.updateScrollAnchor(key: cacheKey(siteKey: siteKey), anchorId: itemId)
    }

    func consumeScrollAnchor() -> String? {
        let anchor = scrollAnchorToRestore
        scrollAnchorToRestore = nil
        return anchor
    }

    func updateSearchVisibility(scrollOffset: CGFloat) {
        let shouldShow = scrollOffset > 36
        if showSearchBar != shouldShow {
            showSearchBar = shouldShow
        }
    }

    func reloadList(configStore: ConfigStore, forceNetwork: Bool = false) async {
        guard let site = configStore.selectedSite else {
            errorMessage = configStore.errorMessage ?? "请先配置订阅并选择站点"
            vodItems = []
            return
        }

        if !forceNetwork, restoreFromCache(siteKey: site.id) {
            return
        }

        activeLoadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        activeLoadTask = Task {
            await performReload(site: site, generation: generation)
        }
        await activeLoadTask?.value
    }

    private func performReload(site: TVSite, generation: Int) async {
        currentPage = 1
        hasMore = true
        isLoading = vodItems.isEmpty
        errorMessage = nil

        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            try Task.checkCancellation()
            let page = try await fetchPage(site: site, page: 1)
            guard generation == loadGeneration, !Task.isCancelled else { return }

            vodItems = page.items
            hasMore = page.hasMore
            currentPage = page.page
            errorMessage = nil
            saveCache(siteKey: site.id)
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration else { return }
            if vodItems.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func loadMore(configStore: ConfigStore) async {
        guard !isLoadingMore, hasMore, let site = configStore.selectedSite else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let page = try await fetchPage(site: site, page: nextPage)
            guard !Task.isCancelled else { return }
            vodItems.append(contentsOf: page.items)
            hasMore = page.hasMore
            currentPage = page.page
            saveCache(siteKey: site.id)
        } catch {
            if vodItems.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectCategory(_ typeId: Int, configStore: ConfigStore) async {
        guard selectedTypeId != typeId else { return }
        selectedTypeId = typeId
        isSearching = false
        searchText = ""

        categoryDebounceTask?.cancel()
        categoryDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            guard let site = configStore.selectedSite else { return }
            if restoreFromCache(siteKey: site.id) {
                return
            }
            await reloadList(configStore: configStore, forceNetwork: true)
        }
        await categoryDebounceTask?.value
    }

    func submitSearch(configStore: ConfigStore) async {
        isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        await reloadList(configStore: configStore, forceNetwork: true)
    }

    func onSiteChanged(configStore: ConfigStore) async {
        guard let site = configStore.selectedSite else { return }
        activeLoadTask?.cancel()
        await loadCategories(apiURL: site.api)
        selectedTypeId = categories.first?.typeId ?? 0
        if restoreFromCache(siteKey: site.id) {
            return
        }
        await reloadList(configStore: configStore, forceNetwork: true)
    }

    private func fetchPage(site: TVSite, page: Int) async throws -> VodListPage {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSearching, !keyword.isEmpty {
            return try await TVBoxAPIService.search(
                apiURL: site.api,
                siteKey: site.id,
                keyword: keyword,
                page: page
            )
        }
        return try await TVBoxAPIService.fetchList(
            apiURL: site.api,
            siteKey: site.id,
            typeId: selectedTypeId,
            page: page
        )
    }

    private func loadCategories(apiURL: String) async {
        do {
            let list = try await TVBoxAPIService.fetchCategories(apiURL: apiURL)
            categories = list
            if !list.contains(where: { $0.typeId == selectedTypeId }) {
                selectedTypeId = list.first?.typeId ?? 0
            }
        } catch {
            categories = [VodCategory(typeId: 0, typeName: "全部")]
            selectedTypeId = 0
        }
    }
}

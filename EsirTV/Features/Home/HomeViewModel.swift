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

    private var currentPage = 1
    private var hasMore = true

    func bootstrap(configStore: ConfigStore) async {
        await configStore.loadSites(force: false)
        guard let site = configStore.selectedSite else { return }
        await loadCategories(apiURL: site.api)
        await reloadList(configStore: configStore)
    }

    func reloadList(configStore: ConfigStore) async {
        guard let site = configStore.selectedSite else {
            errorMessage = configStore.errorMessage ?? "请先配置订阅并选择站点"
            vodItems = []
            return
        }

        currentPage = 1
        hasMore = true
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page: VodListPage
            if isSearching, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                page = try await TVBoxAPIService.search(
                    apiURL: site.api,
                    siteKey: site.id,
                    keyword: searchText,
                    page: currentPage
                )
            } else {
                page = try await TVBoxAPIService.fetchList(
                    apiURL: site.api,
                    siteKey: site.id,
                    typeId: selectedTypeId,
                    page: currentPage
                )
            }
            vodItems = page.items
            hasMore = page.hasMore
            currentPage = page.page
        } catch {
            errorMessage = error.localizedDescription
            vodItems = []
        }
    }

    func loadMore(configStore: ConfigStore) async {
        guard !isLoadingMore, hasMore, let site = configStore.selectedSite else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        let nextPage = currentPage + 1
        do {
            let page: VodListPage
            if isSearching, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                page = try await TVBoxAPIService.search(
                    apiURL: site.api,
                    siteKey: site.id,
                    keyword: searchText,
                    page: nextPage
                )
            } else {
                page = try await TVBoxAPIService.fetchList(
                    apiURL: site.api,
                    siteKey: site.id,
                    typeId: selectedTypeId,
                    page: nextPage
                )
            }
            vodItems.append(contentsOf: page.items)
            hasMore = page.hasMore
            currentPage = page.page
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectCategory(_ typeId: Int, configStore: ConfigStore) async {
        selectedTypeId = typeId
        isSearching = false
        await reloadList(configStore: configStore)
    }

    func submitSearch(configStore: ConfigStore) async {
        isSearching = true
        await reloadList(configStore: configStore)
    }

    func onSiteChanged(configStore: ConfigStore) async {
        guard let site = configStore.selectedSite else { return }
        await loadCategories(apiURL: site.api)
        selectedTypeId = categories.first?.typeId ?? 0
        await reloadList(configStore: configStore)
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

//
//  HomeView.swift
//  EsirTV
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var viewModel = HomeViewModel()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !configStore.isConfigured {
                    configRequiredView
                } else {
                    mainContent
                }
            }
            .navigationTitle("主页")
            .toolbar { toolbarContent }
            .searchable(text: $viewModel.searchText, prompt: "搜索影片")
            .onSubmit(of: .search) {
                Task { await viewModel.submitSearch(configStore: configStore) }
            }
            .task {
                await viewModel.bootstrap(configStore: configStore)
            }
            .refreshable {
                await configStore.loadSites(force: true)
                await viewModel.onSiteChanged(configStore: configStore)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if !viewModel.categories.isEmpty {
                categoryBar
            }

            if viewModel.isLoading && viewModel.vodItems.isEmpty {
                Spacer()
                ProgressView("加载中…")
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.vodItems.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "exclamationmark.triangle",
                    title: "加载失败",
                    message: error
                )
                Spacer()
            } else if viewModel.vodItems.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "film",
                    title: "暂无内容",
                    message: "切换分类或搜索试试"
                )
                Spacer()
            } else {
                posterGrid
            }
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    Button {
                        Task {
                            await viewModel.selectCategory(category.typeId, configStore: configStore)
                        }
                    } label: {
                        Text(category.typeName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedTypeId == category.typeId
                                    ? Color.accentColor
                                    : Color(.tertiarySystemFill)
                            )
                            .foregroundColor(
                                viewModel.selectedTypeId == category.typeId ? .white : .primary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var posterGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 14) {
                ForEach(viewModel.vodItems) { item in
                    NavigationLink {
                        MediaDetailView(listItem: item)
                    } label: {
                        MediaPosterView(item: item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == viewModel.vodItems.last?.id {
                            Task { await viewModel.loadMore(configStore: configStore) }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if viewModel.isLoadingMore {
                ProgressView()
                    .padding()
            }
        }
    }

    private var configRequiredView: some View {
        EmptyStateView(
            systemImage: "link",
            title: "未配置订阅",
            message: "请前往「设置 → 配置管理」添加 TVBox 订阅链接"
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if configStore.isConfigured, !configStore.sites.isEmpty {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("站点", selection: Binding(
                        get: { configStore.selectedSiteKey },
                        set: { newKey in
                            if let site = configStore.sites.first(where: { $0.id == newKey }) {
                                configStore.selectSite(site)
                                Task { await viewModel.onSiteChanged(configStore: configStore) }
                            }
                        }
                    )) {
                        ForEach(configStore.sites) { site in
                            Text(site.name).tag(site.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(configStore.selectedSite?.name ?? "站点")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(ConfigStore())
        .environmentObject(FavoritesStore())
}

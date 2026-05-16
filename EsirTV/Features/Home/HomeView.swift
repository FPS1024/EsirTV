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
            .navigationBarHidden(true)
            .task {
                await viewModel.bootstrap(configStore: configStore)
            }
        }
    }

    // MARK: - 布局：顶栏固定透明 + 分类固定 + 中间海报滚动

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            homeTopBar

            if !viewModel.categories.isEmpty {
                categoryBar
            }

            posterScrollArea
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSearchBar)
    }

    /// 顶部透明栏：主页 + 站点（固定不滚动）
    private var homeTopBar: some View {
        HStack(spacing: 12) {
            Text("主页")
                .font(.headline.weight(.bold))

            Spacer()

            sitePicker
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.clear)
    }

    @ViewBuilder
    private var sitePicker: some View {
        if configStore.isConfigured, !configStore.sites.isEmpty {
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
                    Text(configStore.selectedSite?.name ?? "选择站点")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }

    /// 影视分类（固定不滚动）
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
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// 中间区域：仅海报墙滚动
    private var posterScrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetReader()

                    if viewModel.showSearchBar {
                        searchBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    scrollableContent
                }
            }
            .coordinateSpace(name: "homeScroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                viewModel.updateSearchVisibility(scrollOffset: offset)
            }
            .refreshable {
                await configStore.loadSites(force: true)
                await viewModel.onSiteChanged(configStore: configStore)
            }
            .onChange(of: viewModel.scrollAnchorToRestore) { anchor in
                guard let anchor else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.none) {
                        proxy.scrollTo(anchor, anchor: .center)
                    }
                    _ = viewModel.consumeScrollAnchor()
                }
            }
            .onAppear {
                if let anchor = viewModel.consumeScrollAnchor() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(anchor, anchor: .center)
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索影片", text: $viewModel.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.submitSearch(configStore: configStore) }
                }
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.isSearching = false
                    Task { await viewModel.reloadList(configStore: configStore, forceNetwork: true) }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var scrollableContent: some View {
        if viewModel.isLoading && viewModel.vodItems.isEmpty {
            ProgressView("加载中…")
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding(.top, 24)
        } else if let error = viewModel.errorMessage, viewModel.vodItems.isEmpty {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "加载失败",
                message: error
            )
            .frame(minHeight: 240)
            .padding(.top, 16)
        } else if viewModel.vodItems.isEmpty {
            EmptyStateView(
                systemImage: "film",
                title: "暂无内容",
                message: "切换分类或下拉显示搜索"
            )
            .frame(minHeight: 240)
            .padding(.top, 16)
        } else {
            posterGrid
        }
    }

    @ViewBuilder
    private var posterGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(viewModel.vodItems) { item in
                NavigationLink {
                    MediaDetailView(listItem: item)
                        .onAppear {
                            if let site = configStore.selectedSite {
                                viewModel.markScrollAnchor(item.id, siteKey: site.id)
                            }
                        }
                } label: {
                    MediaPosterView(item: item)
                }
                .buttonStyle(.plain)
                .id(item.id)
                .onAppear {
                    if item.id == viewModel.vodItems.last?.id {
                        Task { await viewModel.loadMore(configStore: configStore) }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 16)

        if viewModel.isLoadingMore {
            ProgressView()
                .padding(.bottom, 16)
        }
    }

    private var configRequiredView: some View {
        EmptyStateView(
            systemImage: "link",
            title: "未配置订阅",
            message: "请前往「设置 → 配置管理」添加 TVBox 订阅链接"
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(ConfigStore())
        .environmentObject(FavoritesStore())
}

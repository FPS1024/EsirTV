//
//  MainTabView.swift
//  EsirTV
//

import SwiftUI

/// 应用根 Tab 容器，iPhone / iPad 通用
struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { tabLabel(for: .home) }
                .tag(AppTab.home)

            HistoryView()
                .tabItem { tabLabel(for: .history) }
                .tag(AppTab.history)

            FavoritesView()
                .tabItem { tabLabel(for: .favorites) }
                .tag(AppTab.favorites)

            SettingsView()
                .tabItem { tabLabel(for: .settings) }
                .tag(AppTab.settings)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(.systemBackground), for: .tabBar)
    }

    @ViewBuilder
    private func tabLabel(for tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppThemeManager())
        .environmentObject(FavoritesStore())
        .environmentObject(ConfigStore())
}

//
//  ContentView.swift
//  EsirTV
//

import SwiftUI

/// 应用根视图入口
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppThemeManager())
        .environmentObject(FavoritesStore())
        .environmentObject(ConfigStore())
}

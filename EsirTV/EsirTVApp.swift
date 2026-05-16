//
//  EsirTVApp.swift
//  EsirTV
//

import SwiftUI

@main
struct EsirTVApp: App {
    @StateObject private var themeManager = AppThemeManager()
    @StateObject private var favoritesStore = FavoritesStore()
    @StateObject private var configStore = ConfigStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(favoritesStore)
                .environmentObject(configStore)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}

//
//  AppThemeManager.swift
//  EsirTV
//

import SwiftUI

/// 全局主题管理，通过 EnvironmentObject 注入各页面
final class AppThemeManager: ObservableObject {
    private static let storageKey = "app.selectedTheme"

    @Published var selectedTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey) }
    }

    var colorScheme: ColorScheme? { selectedTheme.colorScheme }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? AppTheme.system.rawValue
        selectedTheme = AppTheme(rawValue: raw) ?? .system
    }
}

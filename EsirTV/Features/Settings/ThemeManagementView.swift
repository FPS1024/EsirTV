//
//  ThemeManagementView.swift
//  EsirTV
//

import SwiftUI

struct ThemeManagementView: View {
    @EnvironmentObject private var themeManager: AppThemeManager

    var body: some View {
        List {
            Section {
                Picker("外观", selection: $themeManager.selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            } footer: {
                Text("更改后立即生效，并会保存在本机。")
            }
        }
        .navigationTitle("主题管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ThemeManagementView()
    }
    .environmentObject(AppThemeManager())
}

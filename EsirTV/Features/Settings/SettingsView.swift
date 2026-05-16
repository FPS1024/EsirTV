//
//  SettingsView.swift
//  EsirTV
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("应用") {
                    NavigationLink {
                        ConfigurationManagementView()
                    } label: {
                        SettingsRow(icon: "doc.text", title: "配置管理", tint: .blue)
                    }

                    NavigationLink {
                        ThemeManagementView()
                    } label: {
                        SettingsRow(icon: "paintbrush.fill", title: "主题管理", tint: .purple)
                    }
                }

                Section("其他") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(icon: "info.circle", title: "关于", tint: .gray)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - 设置行样式

struct SettingsRow: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppThemeManager())
        .environmentObject(ConfigStore())
}

//
//  AppTab.swift
//  EsirTV
//

import Foundation

/// 主导航 Tab 定义
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case history
    case favorites
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "主页"
        case .history: "历史记录"
        case .favorites: "收藏"
        case .settings: "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.fill"
        case .favorites: "heart.fill"
        case .settings: "gearshape.fill"
        }
    }
}

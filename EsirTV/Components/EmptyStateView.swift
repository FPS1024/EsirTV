//
//  EmptyStateView.swift
//  EsirTV
//

import SwiftUI

/// 通用空状态占位（iOS 16 兼容，替代 ContentUnavailableView）
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.title3.bold())

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        systemImage: "clock",
        title: "暂无记录",
        message: "观看过的内容会显示在这里"
    )
}

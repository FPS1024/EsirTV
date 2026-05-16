//
//  FavoritesStore.swift
//  EsirTV
//

import Combine
import Foundation

/// 收藏（本地持久化，键为 site:vodId）
final class FavoritesStore: ObservableObject {
    private static let storageKey = "app.favorites.vod"

    @Published private(set) var items: [VodItem] = []

    init() {
        load()
    }

    func isFavorite(_ item: VodItem) -> Bool {
        items.contains { $0.id == item.id }
    }

    func toggle(_ item: VodItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else {
            items.insert(item, at: 0)
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        items = (try? JSONDecoder().decode([VodItem].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

//
//  VodDetailCache.swift
//  EsirTV
//

import Foundation

/// 详情页缓存（内存，加快二次打开）
@MainActor
final class VodDetailCache {
    static let shared = VodDetailCache()

    private var storage: [String: VodDetail] = [:]

    func detail(for listItem: VodItem) -> VodDetail? {
        storage[listItem.id]
    }

    func save(_ detail: VodDetail) {
        storage[detail.id] = detail
    }

    func remove(id: String) {
        storage.removeValue(forKey: id)
    }
}

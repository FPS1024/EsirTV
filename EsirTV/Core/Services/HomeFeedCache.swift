//
//  HomeFeedCache.swift
//  EsirTV
//

import Foundation

struct HomeFeedCacheKey: Hashable {
    let siteKey: String
    let typeId: Int
    let searchQuery: String

    init(siteKey: String, typeId: Int, searchQuery: String = "") {
        self.siteKey = siteKey
        self.typeId = typeId
        self.searchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct CachedFeedState {
    var items: [VodItem]
    var currentPage: Int
    var hasMore: Bool
    var scrollAnchorId: String?
}

/// 主页列表与滚动位置缓存（内存）
@MainActor
final class HomeFeedCache {
    static let shared = HomeFeedCache()

    private var feeds: [HomeFeedCacheKey: CachedFeedState] = [:]

    func state(for key: HomeFeedCacheKey) -> CachedFeedState? {
        feeds[key]
    }

    func save(
        key: HomeFeedCacheKey,
        items: [VodItem],
        currentPage: Int,
        hasMore: Bool,
        scrollAnchorId: String?
    ) {
        feeds[key] = CachedFeedState(
            items: items,
            currentPage: currentPage,
            hasMore: hasMore,
            scrollAnchorId: scrollAnchorId
        )
    }

    func updateScrollAnchor(key: HomeFeedCacheKey, anchorId: String?) {
        guard var state = feeds[key] else { return }
        state.scrollAnchorId = anchorId
        feeds[key] = state
    }
}

//
//  TVBoxAPIService.swift
//  EsirTV
//

import Foundation

/// 站点 API：分类、列表、搜索、详情
enum TVBoxAPIService {
    static func fetchCategories(apiURL: String) async throws -> [VodCategory] {
        let url = buildURL(base: apiURL, params: ["ac": "list", "t": "0", "pg": "1"])
        let data = try await TVBoxHTTPClient.fetchData(urlString: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let classes = json["class"] as? [[String: Any]] ?? []
        return classes.compactMap(VodCategory.init(dictionary:))
            .sorted { $0.typeId < $1.typeId }
    }

    static func fetchList(
        apiURL: String,
        siteKey: String,
        typeId: Int,
        page: Int
    ) async throws -> VodListPage {
        let url = buildURL(base: apiURL, params: ["ac": "list", "t": String(typeId), "pg": String(page)])
        let data = try await TVBoxHTTPClient.fetchData(urlString: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let list = json["list"] as? [[String: Any]] ?? []
        let items = list.compactMap { VodItem(siteKey: siteKey, dictionary: $0) }
        let currentPage = FlexibleJSON.int(from: json["page"], default: page)
        let pageCount = max(1, FlexibleJSON.int(from: json["pagecount"], default: 1))
        return VodListPage(
            items: items,
            page: currentPage,
            pageCount: pageCount,
            hasMore: currentPage < pageCount
        )
    }

    static func search(
        apiURL: String,
        siteKey: String,
        keyword: String,
        page: Int
    ) async throws -> VodListPage {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let url = buildURL(base: apiURL, params: [
            "ac": "list",
            "wd": encoded,
            "pg": String(page),
        ])
        let data = try await TVBoxHTTPClient.fetchData(urlString: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let list = json["list"] as? [[String: Any]] ?? []
        let items = list.compactMap { VodItem(siteKey: siteKey, dictionary: $0) }
        let currentPage = FlexibleJSON.int(from: json["page"], default: page)
        let pageCount = max(1, FlexibleJSON.int(from: json["pagecount"], default: 1))
        return VodListPage(
            items: items,
            page: currentPage,
            pageCount: pageCount,
            hasMore: currentPage < pageCount
        )
    }

    static func fetchDetail(apiURL: String, siteKey: String, vodId: String) async throws -> VodDetail {
        let url = buildURL(base: apiURL, params: ["ac": "detail", "ids": vodId])
        let data = try await TVBoxHTTPClient.fetchData(urlString: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let list = json["list"] as? [[String: Any]] ?? []
        guard let first = list.first, let detail = VodDetail(siteKey: siteKey, dictionary: first) else {
            throw TVBoxHTTPError.decodeFailed
        }
        return detail
    }

    private static func buildURL(base: String, params: [String: String]) -> String {
        guard var components = URLComponents(string: base) else {
            var query = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            if base.contains("?") {
                return "\(base)&\(query)"
            }
            return "\(base)?\(query)"
        }

        var queryItems = components.queryItems ?? []
        for (key, value) in params {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? base
    }
}

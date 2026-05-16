//
//  TVSite.swift
//  EsirTV
//

import Foundation

/// 配置订阅中的单个影视站点
struct TVSite: Identifiable, Hashable, Codable {
    var key: String
    var name: String
    var api: String

    var id: String { key.isEmpty ? name : key }

    init(key: String = "", name: String = "", api: String = "") {
        self.key = key
        self.name = name
        self.api = api
    }

    init?(dictionary: [String: Any]) {
        let key = FlexibleJSON.string(from: dictionary["key"])
        let name = FlexibleJSON.string(from: dictionary["name"])
        let api = FlexibleJSON.string(from: dictionary["api"])
        guard !api.isEmpty else { return nil }
        self.key = key.isEmpty ? name : key
        self.name = name.isEmpty ? key : name
        self.api = api
    }
}

enum TVBoxConfigParser {
    static func extractSites(from json: Any) -> [TVSite] {
        var rawSites: [[String: Any]] = []

        if let array = json as? [[String: Any]],
           let first = array.first,
           let sites = first["sites"] as? [[String: Any]] {
            rawSites = sites
        } else if let dict = json as? [String: Any],
                  let sites = dict["sites"] as? [[String: Any]] {
            rawSites = sites
        }

        return rawSites.compactMap(TVSite.init(dictionary:))
    }
}

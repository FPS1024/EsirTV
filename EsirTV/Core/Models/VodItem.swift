//
//  VodItem.swift
//  EsirTV
//

import Foundation

/// 列表中的影视条目（海报墙数据源）
struct VodItem: Identifiable, Hashable, Codable {
    let siteKey: String
    let vodId: String
    var title: String
    var posterURL: String
    var typeName: String
    var vodYear: String
    var vodArea: String
    var remarks: String

    var id: String { "\(siteKey):\(vodId)" }

    var subtitle: String? {
        let parts = [typeName, vodYear, remarks].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    init(
        siteKey: String,
        vodId: String,
        title: String,
        posterURL: String = "",
        typeName: String = "",
        vodYear: String = "",
        vodArea: String = "",
        remarks: String = ""
    ) {
        self.siteKey = siteKey
        self.vodId = vodId
        self.title = title
        self.posterURL = posterURL
        self.typeName = typeName
        self.vodYear = vodYear
        self.vodArea = vodArea
        self.remarks = remarks
    }

    init?(siteKey: String, dictionary: [String: Any]) {
        let vodId = FlexibleJSON.string(from: dictionary["vod_id"])
        let title = FlexibleJSON.string(from: dictionary["vod_name"])
        guard !vodId.isEmpty, !title.isEmpty else { return nil }

        self.siteKey = siteKey
        self.vodId = vodId
        self.title = title
        posterURL = FlexibleJSON.string(from: dictionary["vod_pic"])
        typeName = FlexibleJSON.string(from: dictionary["type_name"])
        vodYear = FlexibleJSON.string(from: dictionary["vod_year"])
        vodArea = FlexibleJSON.string(from: dictionary["vod_area"])
        remarks = FlexibleJSON.string(from: dictionary["vod_remarks"])
    }
}

struct VodListPage {
    let items: [VodItem]
    let page: Int
    let pageCount: Int
    let hasMore: Bool
}

//
//  VodDetail.swift
//  EsirTV
//

import Foundation

/// 详情页完整数据
struct VodDetail: Identifiable, Hashable {
    let siteKey: String
    let vodId: String
    var title: String
    var posterURL: String
    var typeName: String
    var vodYear: String
    var vodArea: String
    var remarks: String
    var synopsis: String
    var playSources: [PlaySource]

    var id: String { "\(siteKey):\(vodId)" }

    var listItem: VodItem {
        VodItem(
            siteKey: siteKey,
            vodId: vodId,
            title: title,
            posterURL: posterURL,
            typeName: typeName,
            vodYear: vodYear,
            vodArea: vodArea,
            remarks: remarks
        )
    }

    var hasEpisodes: Bool {
        playSources.contains { !$0.episodes.isEmpty }
    }

    var allEpisodes: [PlayEpisode] {
        playSources.flatMap(\.episodes)
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

        let content = FlexibleJSON.string(from: dictionary["vod_content"])
        synopsis = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let playFrom = FlexibleJSON.string(from: dictionary["vod_play_from"])
        let playUrl = FlexibleJSON.string(from: dictionary["vod_play_url"])
        playSources = PlaySourceParser.parse(playFrom: playFrom, playUrl: playUrl)
    }
}

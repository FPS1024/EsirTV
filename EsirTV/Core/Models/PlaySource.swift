//
//  PlaySource.swift
//  EsirTV
//

import Foundation

/// 单个播放线路下的分集
struct PlayEpisode: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var episodeNumber: Int
    var playURL: String

    var displayTitle: String {
        name.isEmpty ? "第\(episodeNumber)集" : name
    }

    init(id: UUID = UUID(), name: String, episodeNumber: Int, playURL: String) {
        self.id = id
        self.name = name
        self.episodeNumber = episodeNumber
        self.playURL = playURL
    }
}

/// 播放源（线路）
struct PlaySource: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var episodes: [PlayEpisode]

    init(id: UUID = UUID(), name: String, episodes: [PlayEpisode]) {
        self.id = id
        self.name = name
        self.episodes = episodes
    }
}

/// 解析 TVBox vod_play_from / vod_play_url
enum PlaySourceParser {
    static func parse(playFrom: String, playUrl: String) -> [PlaySource] {
        let sourceNames = playFrom
            .components(separatedBy: "$$$")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let urlGroups = playUrl
            .components(separatedBy: "$$$")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !urlGroups.isEmpty else { return [] }

        var sources: [PlaySource] = []
        for (index, group) in urlGroups.enumerated() {
            let name = index < sourceNames.count ? sourceNames[index] : "线路\(index + 1)"
            let episodes = parseEpisodeGroup(group)
            if !episodes.isEmpty {
                sources.append(PlaySource(name: name, episodes: episodes))
            }
        }
        return sources
    }

    private static func parseEpisodeGroup(_ group: String) -> [PlayEpisode] {
        let entries = group
            .components(separatedBy: "#")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return entries.enumerated().compactMap { index, entry in
            let (name, url) = splitNameAndURL(entry)
            guard !url.isEmpty else { return nil }
            return PlayEpisode(
                name: name.isEmpty ? "第\(index + 1)集" : name,
                episodeNumber: index + 1,
                playURL: url
            )
        }
    }

    private static func splitNameAndURL(_ entry: String) -> (String, String) {
        if let range = entry.range(of: "$", options: .backwards) {
            let name = String(entry[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let url = String(entry[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (name, url)
        }
        return ("", entry)
    }
}

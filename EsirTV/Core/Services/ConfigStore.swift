//
//  ConfigStore.swift
//  EsirTV
//

import Combine
import Foundation

/// 订阅配置管理：保存链接、解析站点列表
@MainActor
final class ConfigStore: ObservableObject {
    private static let configURLKey = "app.tvbox.configUrl"
    private static let selectedSiteKey = "app.tvbox.selectedSite"

    @Published private(set) var configURL: String = ""
    @Published private(set) var sites: [TVSite] = []
    @Published var selectedSiteKey: String = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var sitesCache: [TVSite]?
    private var sitesCacheTime: Date?
    private let cacheDuration: TimeInterval = 5 * 60

    init() {
        configURL = UserDefaults.standard.string(forKey: Self.configURLKey) ?? ""
        selectedSiteKey = UserDefaults.standard.string(forKey: Self.selectedSiteKey) ?? ""
    }

    var selectedSite: TVSite? {
        sites.first { $0.id == selectedSiteKey } ?? sites.first
    }

    var isConfigured: Bool {
        !configURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveConfigURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        configURL = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.configURLKey)
        invalidateCache()
    }

    func selectSite(_ site: TVSite) {
        selectedSiteKey = site.id
        UserDefaults.standard.set(site.id, forKey: Self.selectedSiteKey)
    }

    func invalidateCache() {
        sitesCache = nil
        sitesCacheTime = nil
        sites = []
    }

    func loadSites(force: Bool = false) async {
        let trimmed = configURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请先在设置中配置订阅链接"
            sites = []
            return
        }

        if !force,
           let cached = sitesCache,
           let time = sitesCacheTime,
           Date().timeIntervalSince(time) < cacheDuration {
            sites = cached
            ensureSelectedSite()
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await TVBoxHTTPClient.fetchData(urlString: trimmed)
            let json = try JSONSerialization.jsonObject(with: data)
            let parsed = TVBoxConfigParser.extractSites(from: json)
            guard !parsed.isEmpty else {
                throw NSError(domain: "ConfigStore", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "配置可访问，但未解析到站点列表",
                ])
            }
            sitesCache = parsed
            sitesCacheTime = Date()
            sites = parsed
            ensureSelectedSite()
        } catch {
            errorMessage = error.localizedDescription
            sites = []
        }
    }

    func testConfigURL(_ url: String) async -> (success: Bool, siteCount: Int, message: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, 0, "链接不能为空")
        }
        guard URL(string: trimmed)?.scheme?.hasPrefix("http") == true else {
            return (false, 0, "必须是 http/https 链接")
        }

        do {
            let data = try await TVBoxHTTPClient.fetchData(urlString: trimmed)
            let json = try JSONSerialization.jsonObject(with: data)
            let parsed = TVBoxConfigParser.extractSites(from: json)
            guard !parsed.isEmpty else {
                return (false, 0, "未解析到站点（sites 为空）")
            }
            return (true, parsed.count, "测试成功")
        } catch {
            return (false, 0, error.localizedDescription)
        }
    }

    private func ensureSelectedSite() {
        if sites.contains(where: { $0.id == selectedSiteKey }) { return }
        if let first = sites.first {
            selectSite(first)
        }
    }
}

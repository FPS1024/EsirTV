//
//  TVBoxHTTPClient.swift
//  EsirTV
//

import Foundation

enum TVBoxHTTPError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "链接无效"
        case .invalidResponse: return "服务器响应异常"
        case .httpStatus(let code): return "请求失败（HTTP \(code)）"
        case .decodeFailed: return "数据解析失败"
        }
    }
}

/// TVBox / 苹果 CMS 通用 HTTP 客户端
enum TVBoxHTTPClient {
    private static let headers: [String: String] = [
        "User-Agent": "okhttp/3.12.0",
        "Accept": "application/json, text/plain, */*",
        "Connection": "close",
    ]

    static func fetchJSON<T: Decodable>(
        urlString: String,
        as type: T.Type = T.self
    ) async throws -> T {
        let data = try await fetchData(urlString: urlString)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw TVBoxHTTPError.decodeFailed
        }
    }

    static func fetchData(urlString: String) async throws -> Data {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw TVBoxHTTPError.invalidURL
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // http 一律走 TCP 直连，彻底绕过 ATS（不依赖 Info.plist）
        if scheme == "http" {
            return try await RawHTTPClient.fetchData(url: url, headers: headers)
        }

        if scheme == "https" {
            return try await fetchDataViaURLSession(url: url, extraHeaders: headers)
        }

        throw TVBoxHTTPError.invalidURL
    }

    private static func fetchDataViaURLSession(
        url: URL,
        extraHeaders: [String: String]
    ) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 20)
        extraHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw TVBoxHTTPError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                throw TVBoxHTTPError.httpStatus(http.statusCode)
            }
            return data
        } catch let error as URLError where error.code == .appTransportSecurityRequiresSecureConnection {
            throw NSError(
                domain: "TVBoxHTTPClient",
                code: error.errorCode,
                userInfo: [
                    NSLocalizedDescriptionKey: "HTTPS 证书或 ATS 限制导致无法访问，请尝试使用 HTTP 配置链接",
                ]
            )
        }
    }

    static func imageReferer(for imageURL: URL) -> String {
        let host = imageURL.host?.lowercased() ?? ""
        if host.hasSuffix("qpic.cn") || host.contains("mmbiz") {
            return "https://mp.weixin.qq.com/"
        }
        if let scheme = imageURL.scheme, let host = imageURL.host {
            return "\(scheme)://\(host)/"
        }
        return "https://www.google.com/"
    }

    static func fetchImageData(urlString: String) async throws -> Data {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw TVBoxHTTPError.invalidURL
        }

        var imageHeaders: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "image/*,*/*;q=0.8",
            "Referer": imageReferer(for: url),
        ]

        if url.scheme?.lowercased() == "http" {
            return try await RawHTTPClient.fetchData(url: url, headers: imageHeaders)
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        imageHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TVBoxHTTPError.invalidResponse
        }
        return data
    }
}

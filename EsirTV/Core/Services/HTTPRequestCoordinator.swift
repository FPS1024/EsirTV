//
//  HTTPRequestCoordinator.swift
//  EsirTV
//

import Foundation

/// 限制并发 HTTP 请求，避免 Connection reset by peer
actor HTTPRequestCoordinator {
    static let shared = HTTPRequestCoordinator()

    private var activeCount = 0
    private let maxConcurrent = 2

    func run<T>(_ operation: () async throws -> T) async throws -> T {
        while activeCount >= maxConcurrent {
            try await Task.sleep(nanoseconds: 80_000_000)
            try Task.checkCancellation()
        }
        activeCount += 1
        defer { activeCount -= 1 }
        return try await operation()
    }

    /// 带重试（针对连接被重置）
    func runWithRetry<T>(
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            try Task.checkCancellation()
            do {
                return try await run(operation)
            } catch {
                lastError = error
                guard attempt < maxAttempts, shouldRetry(error) else { break }
                try await Task.sleep(nanoseconds: UInt64(attempt) * 300_000_000)
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet:
                return true
            default:
                break
            }
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("reset") || text.contains("connection") || text.contains("timed out")
    }
}

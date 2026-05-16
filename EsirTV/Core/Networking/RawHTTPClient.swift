//
//  RawHTTPClient.swift
//  EsirTV
//
//  通过 TCP 直连 HTTP/1.1，绕过 URL Loading System 与 ATS。
//

import Foundation
import Network
import os

enum RawHTTPClient {
    private final class ResumeGate: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: false)

        func runOnce(_ action: () -> Void) -> Bool {
            lock.withLock { state -> Bool in
                guard !state else { return false }
                state = true
                action()
                return true
            }
        }
    }
    static func fetchData(
        url: URL,
        headers: [String: String],
        timeout: TimeInterval = 20
    ) async throws -> Data {
        guard url.scheme?.lowercased() == "http" else {
            throw TVBoxHTTPError.invalidURL
        }
        guard let host = url.host, !host.isEmpty else {
            throw TVBoxHTTPError.invalidURL
        }

        let port = UInt16(url.port ?? 80)
        let path = url.path.isEmpty ? "/" : url.path
        let pathWithQuery: String
        if let query = url.query, !query.isEmpty {
            pathWithQuery = "\(path)?\(query)"
        } else {
            pathWithQuery = path
        }

        var requestHeaders = headers
        requestHeaders["Host"] = port == 80 ? host : "\(host):\(port)"
        requestHeaders["Connection"] = "close"
        if requestHeaders["Accept-Encoding"] == nil {
            requestHeaders["Accept-Encoding"] = "identity"
        }

        let headerBlock = requestHeaders
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\r\n")
        let requestString = "GET \(pathWithQuery) HTTP/1.1\r\n\(headerBlock)\r\n\r\n"
        guard let requestData = requestString.data(using: .utf8) else {
            throw TVBoxHTTPError.invalidURL
        }

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await performRequest(
                    host: host,
                    port: port,
                    requestData: requestData
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw URLError(.timedOut)
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private static func performRequest(
        host: String,
        port: UInt16,
        requestData: Data
    ) async throws -> Data {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port) ?? 80,
            using: .tcp
        )

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            var received = Data()
            let gate = ResumeGate()

            func resumeOnce(_ result: Result<Data, Error>) {
                gate.runOnce {
                    connection.cancel()
                    continuation.resume(with: result)
                }
            }

            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { data, _, isComplete, error in
                    if let error {
                        resumeOnce(.failure(error))
                        return
                    }
                    if let data, !data.isEmpty {
                        received.append(data)
                    }
                    if isComplete {
                        do {
                            let body = try parseHTTPResponseBody(received)
                            resumeOnce(.success(body))
                        } catch {
                            resumeOnce(.failure(error))
                        }
                        return
                    }
                    receiveNext()
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: requestData, completion: .contentProcessed { sendError in
                        if let sendError {
                            resumeOnce(.failure(sendError))
                        } else {
                            receiveNext()
                        }
                    })
                case .failed(let error):
                    resumeOnce(.failure(error))
                case .cancelled:
                    resumeOnce(.failure(TVBoxHTTPError.invalidResponse))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    private static func parseHTTPResponseBody(_ data: Data) throws -> Data {
        let separator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        guard let range = data.range(of: separator) else {
            throw TVBoxHTTPError.invalidResponse
        }

        let headerData = data.subdata(in: 0..<range.lowerBound)
        let bodyData = data.subdata(in: range.upperBound..<data.count)
        let headerText = String(data: headerData, encoding: .utf8) ?? ""

        let statusLine = headerText.components(separatedBy: "\r\n").first ?? ""
        let statusCode = parseStatusCode(from: statusLine)
        guard (200...299).contains(statusCode) else {
            throw TVBoxHTTPError.httpStatus(statusCode)
        }

        let lowerHeaders = headerText.lowercased()
        if lowerHeaders.contains("transfer-encoding: chunked") {
            return decodeChunkedBody(bodyData)
        }

        return bodyData
    }

    private static func parseStatusCode(from statusLine: String) -> Int {
        let parts = statusLine.split(separator: " ")
        guard parts.count >= 2, let code = Int(parts[1]) else { return 500 }
        return code
    }

    private static func decodeChunkedBody(_ data: Data) -> Data {
        var result = Data()
        var index = data.startIndex

        while index < data.endIndex {
            guard let lineEnd = data[index...].firstIndex(of: 0x0A) else { break }
            let lineData = data[index..<lineEnd]
            let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            index = data.index(after: lineEnd)
            if line.isEmpty { continue }

            guard let chunkSize = Int(line, radix: 16) else { break }
            if chunkSize == 0 { break }

            let chunkEnd = data.index(index, offsetBy: chunkSize, limitedBy: data.endIndex) ?? data.endIndex
            result.append(data[index..<chunkEnd])
            index = chunkEnd
            if index < data.endIndex, data[index] == 0x0D {
                index = data.index(index, offsetBy: 1)
            }
            if index < data.endIndex, data[index] == 0x0A {
                index = data.index(index, offsetBy: 1)
            }
        }

        return result
    }
}

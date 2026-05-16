//
//  SSDPDiscovery.swift
//  EsirTV
//

import Foundation
import Darwin

enum SSDPDiscovery {
    private static let multicastHost = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900

    static func discoverRenderers(timeout: TimeInterval = 2.5) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: performDiscovery(timeout: timeout))
            }
        }
    }

    private static func performDiscovery(timeout: TimeInterval) -> [String] {
        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else { return [] }
        defer { close(socketFD) }

        var reuse: Int32 = 1
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var bindAddr = sockaddr_in()
        bindAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0
        bindAddr.sin_addr.s_addr = in_addr_t(0)
        withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var timeVal = timeval(tv_sec: 0, tv_usec: Int32(timeout * 1_000_000))
        setsockopt(socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeVal, socklen_t(MemoryLayout<timeval>.size))

        let searchTargets = [
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "upnp:rootdevice",
        ]
        for target in searchTargets {
            sendMulticast(buildMSearch(target: target), socketFD: socketFD)
        }

        var locations: [String] = []
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            let received = recv(socketFD, &buffer, buffer.count, 0)
            if received <= 0 { break }
            let text = String(bytes: buffer.prefix(received), encoding: .utf8) ?? ""
            if let location = parseLocation(from: text), !locations.contains(location) {
                locations.append(location)
            }
        }
        return locations
    }

    private static func buildMSearch(target: String) -> String {
        """
        M-SEARCH * HTTP/1.1\r
        HOST: \(multicastHost):\(multicastPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(target)\r
        \r\n
        """
    }

    private static func sendMulticast(_ message: String, socketFD: Int32) {
        guard let data = message.data(using: .utf8) else { return }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(multicastPort).bigEndian)
        inet_pton(AF_INET, multicastHost, &addr.sin_addr)

        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { ptr in
                    _ = sendto(socketFD, base, data.count, 0, ptr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private static func parseLocation(from response: String) -> String? {
        for line in response.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("location:") {
                return line.dropFirst("location:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

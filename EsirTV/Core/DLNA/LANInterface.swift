//
//  LANInterface.swift
//  EsirTV
//

import Darwin
import Foundation

struct LANIPv4Interface: Hashable {
    let name: String
    let address: String
    let broadcast: String?
}

enum LANInterfaceEnumerator {
    static func activeIPv4Interfaces() -> [LANIPv4Interface] {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return [] }
        defer { freeifaddrs(ifaddrPtr) }

        var byName: [String: (addr: in_addr, mask: in_addr)] = [:]
        var ptr: UnsafeMutablePointer<ifaddrs>? = first

        while let ifa = ptr?.pointee {
            let flags = Int32(ifa.ifa_flags)
            let name = String(cString: ifa.ifa_name)
            if (flags & IFF_UP) != 0,
               (flags & IFF_LOOPBACK) == 0,
               let addrPtr = ifa.ifa_addr,
               addrPtr.pointee.sa_family == sa_family_t(AF_INET) {
                let sin = addrPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                if let maskPtr = ifa.ifa_netmask,
                   maskPtr.pointee.sa_family == sa_family_t(AF_INET) {
                    let mask = maskPtr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                    byName[name] = (sin.sin_addr, mask.sin_addr)
                }
            }
            ptr = ifa.ifa_next.map { UnsafeMutablePointer($0) }
        }

        var result: [LANIPv4Interface] = []
        for (name, pair) in byName {
            let ip = pair.addr.s_addr
            if ip == 0 || (ip & 0xFF) == 127 { continue }
            guard let address = ipv4String(ip) else { continue }
            let broadcast = ipv4String(ip | ~pair.mask.s_addr)
            result.append(LANIPv4Interface(name: name, address: address, broadcast: broadcast))
        }
        return result.sorted { $0.name < $1.name }
    }

    static var primaryGatewayHint: String? {
        guard let ip = activeIPv4Interfaces().first?.address else { return nil }
        var parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        parts[3] = "1"
        return parts.joined(separator: ".")
    }

    private static func ipv4String(_ addr: in_addr_t) -> String? {
        var a = in_addr(s_addr: addr)
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &a, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
            return nil
        }
        return String(cString: buffer)
    }
}

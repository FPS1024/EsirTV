//
//  DLNADeviceProbe.swift
//  EsirTV
//

import Foundation

enum DLNADeviceProbe {
    private static let commonPorts = [49152, 80, 8080, 9008, 8200, 5000, 5200, 1599, 2869]
    private static let commonPaths = [
        "/description.xml",
        "/rootDesc.xml",
        "/dmrDesc.xml",
        "/DeviceDescription.xml",
        "/upnp/dev.xml",
    ]

    static func probe(ip: String) async -> DLNADevice? {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("http") {
            return await DLNAManager.fetchDevice(at: trimmed)
        }

        for port in commonPorts {
            for path in commonPaths {
                let url = "http://\(trimmed):\(port)\(path)"
                if let device = await DLNAManager.fetchDevice(at: url) {
                    return device
                }
            }
        }
        return nil
    }
}

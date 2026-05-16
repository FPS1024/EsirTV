//
//  DLNAManager.swift
//  EsirTV
//

import Foundation

@MainActor
final class DLNAManager: ObservableObject {
    static let shared = DLNAManager()

    @Published private(set) var devices: [DLNADevice] = []
    @Published private(set) var isDiscovering = false
    @Published var lastError: String?

    private init() {}

    func discoverDevices() async {
        isDiscovering = true
        lastError = nil
        defer { isDiscovering = false }

        let locations = await SSDPDiscovery.discoverRenderers(timeout: 2.5)
        var found: [DLNADevice] = []
        var seen = Set<String>()

        await withTaskGroup(of: DLNADevice?.self) { group in
            for location in locations {
                group.addTask {
                    await Self.fetchDevice(at: location)
                }
            }
            for await device in group {
                guard let device, seen.insert(device.id).inserted else { continue }
                found.append(device)
            }
        }

        devices = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if devices.isEmpty {
            lastError = "未发现 DLNA 设备，请确认电视与手机在同一 Wi‑Fi"
        }
    }

    func cast(mediaURL: URL, title: String, to device: DLNADevice) async throws {
        try await DLNACastService.cast(mediaURL: mediaURL, title: title, to: device)
    }

    private static func fetchDevice(at location: String) async -> DLNADevice? {
        guard let url = URL(string: location) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(for: request)
        } catch {
            return nil
        }

        guard let xml = String(data: data, encoding: .utf8),
              let parsed = UPnPXMLParser.parseDeviceDescription(xml, baseLocation: url),
              let controlURL = parsed.avTransportControlURL else {
            return nil
        }

        return DLNADevice(
            id: parsed.udn,
            name: parsed.friendlyName,
            location: location,
            controlURL: controlURL,
            serviceType: parsed.avTransportServiceType
                ?? "urn:schemas-upnp-org:service:AVTransport:1"
        )
    }
}

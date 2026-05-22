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

        await LocalNetworkPermission.requestAccess()
        try? await Task.sleep(nanoseconds: 400_000_000)

        let locations = await SSDPDiscovery.discoverRenderers(timeout: 5)
        var found = await resolveDevices(from: locations)

        if found.isEmpty, let broadcast = LANInterfaceEnumerator.activeIPv4Interfaces().first?.broadcast {
            let fallback = await DLNADeviceProbe.probe(ip: broadcast)
            if let fallback {
                found = [fallback]
            }
        }

        devices = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if devices.isEmpty {
            lastError = """
            未发现 DLNA 设备。请确认：
            1. 手机与电视连接同一 Wi‑Fi（勿用访客网络）
            2. 在「设置 → 隐私与安全性 → 本地网络」中允许 EsirTV
            3. 电视已开启 DLNA / 投屏 / 媒体共享
            也可在下方手动输入电视 IP 地址
            """
        }
    }

    func addManualDevice(ip: String) async -> Bool {
        isDiscovering = true
        lastError = nil
        defer { isDiscovering = false }

        await LocalNetworkPermission.requestAccess()
        try? await Task.sleep(nanoseconds: 300_000_000)

        guard let device = await DLNADeviceProbe.probe(ip: ip) else {
            lastError = "无法连接 \(ip)，请检查 IP 是否正确、电视是否开启 DLNA"
            return false
        }

        if !devices.contains(where: { $0.id == device.id }) {
            devices.append(device)
            devices.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        lastError = nil
        return true
    }

    func cast(mediaURL: URL, title: String, to device: DLNADevice) async throws {
        try await DLNACastService.cast(mediaURL: mediaURL, title: title, to: device)
    }

    private func resolveDevices(from locations: [String]) async -> [DLNADevice] {
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
        return found
    }

    static func fetchDevice(at location: String) async -> DLNADevice? {
        guard let url = URL(string: location) else { return nil }

        let data: Data
        do {
            if url.scheme?.lowercased() == "http", url.host?.contains(".") == true {
                data = try await RawHTTPClient.fetchData(url: url, headers: [:], timeout: 6)
            } else {
                var request = URLRequest(url: url)
                request.timeoutInterval = 8
                (data, _) = try await URLSession.shared.data(for: request)
            }
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

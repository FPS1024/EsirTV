//
//  DLNACastService.swift
//  EsirTV
//

import Foundation

enum DLNACastService {
    enum CastError: LocalizedError {
        case invalidURL
        case soapFailed(String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "播放地址无效"
            case .soapFailed(let detail): return "投屏失败：\(detail)"
            case .network(let detail): return detail
            }
        }
    }

    static func cast(
        mediaURL: URL,
        title: String,
        to device: DLNADevice
    ) async throws {
        guard let controlURL = URL(string: device.controlURL) else {
            throw CastError.invalidURL
        }

        let metadata = didlLiteMetadata(title: title, url: mediaURL.absoluteString)
        try await setAVTransportURI(
            controlURL: controlURL,
            serviceType: device.serviceType,
            mediaURL: mediaURL.absoluteString,
            metadata: metadata
        )
        try await play(controlURL: controlURL, serviceType: device.serviceType)
    }

    private static func setAVTransportURI(
        controlURL: URL,
        serviceType: String,
        mediaURL: String,
        metadata: String
    ) async throws {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:SetAVTransportURI xmlns:u="\(serviceType)">
        <InstanceID>0</InstanceID>
        <CurrentURI>\(escapeXML(mediaURL))</CurrentURI>
        <CurrentURIMetaData>\(escapeXML(metadata))</CurrentURIMetaData>
        </u:SetAVTransportURI>
        </s:Body>
        </s:Envelope>
        """

        try await soapRequest(
            controlURL: controlURL,
            serviceType: serviceType,
            action: "SetAVTransportURI",
            body: body
        )
    }

    private static func play(controlURL: URL, serviceType: String) async throws {
        let body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:Play xmlns:u="\(serviceType)">
        <InstanceID>0</InstanceID>
        <Speed>1</Speed>
        </u:Play>
        </s:Body>
        </s:Envelope>
        """

        try await soapRequest(
            controlURL: controlURL,
            serviceType: serviceType,
            action: "Play",
            body: body
        )
    }

    private static func soapRequest(
        controlURL: URL,
        serviceType: String,
        action: String,
        body: String
    ) async throws {
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(serviceType)#\(action)\"", forHTTPHeaderField: "SOAPAction")
        request.httpBody = body.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CastError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CastError.soapFailed("无响应")
        }

        let responseText = String(data: data, encoding: .utf8) ?? ""
        if http.statusCode >= 400 {
            throw CastError.soapFailed("HTTP \(http.statusCode)")
        }
        if responseText.contains("<UPnPError>") || responseText.contains("errorCode") {
            throw CastError.soapFailed("设备拒绝播放")
        }
    }

    private static func didlLiteMetadata(title: String, url: String) -> String {
        let safeTitle = escapeXML(title)
        let safeURL = escapeXML(url)
        return """
        &lt;DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/"&gt;
        &lt;item id="0" parentID="-1" restricted="1"&gt;
        &lt;dc:title&gt;\(safeTitle)&lt;/dc:title&gt;
        &lt;res protocolInfo="http-get:*:video/*:*"&gt;\(safeURL)&lt;/res&gt;
        &lt;upnp:class&gt;object.item.videoItem&lt;/upnp:class&gt;
        &lt;/item&gt;
        &lt;/DIDL-Lite&gt;
        """
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

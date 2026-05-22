//
//  UPnPXMLParser.swift
//  EsirTV
//

import Foundation

enum UPnPXMLParser {
    struct ParsedDevice {
        var friendlyName: String
        var udn: String
        var avTransportControlURL: String?
        var avTransportServiceType: String?
    }

    static func parseDeviceDescription(_ xml: String, baseLocation: URL) -> ParsedDevice? {
        let friendlyName = extractTag("friendlyName", from: xml) ?? "DLNA 设备"
        let udn = extractTag("UDN", from: xml) ?? baseLocation.absoluteString

        var controlURL: String?
        var serviceType: String?

        let blocks = extractAllServiceBlocks(xml)
        let avBlock = blocks.first { block in
            block.localizedCaseInsensitiveContains("AVTransport")
                || block.localizedCaseInsensitiveContains("urn:upnp-org:serviceId:AVTransport")
        } ?? blocks.first

        if let serviceBlock = avBlock {
            serviceType = extractTag("serviceType", from: serviceBlock)
            if let rawControl = extractTag("controlURL", from: serviceBlock) {
                controlURL = resolveURL(base: baseLocation, relative: rawControl)
            }
        }

        return ParsedDevice(
            friendlyName: friendlyName,
            udn: udn,
            avTransportControlURL: controlURL,
            avTransportServiceType: serviceType
                ?? "urn:schemas-upnp-org:service:AVTransport:1"
        )
    }

    private static func extractAllServiceBlocks(_ xml: String) -> [String] {
        let pattern = "<service[\\s\\S]*?</service>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        return regex.matches(in: xml, range: range).compactMap { match in
            guard let blockRange = Range(match.range, in: xml) else { return nil }
            return String(xml[blockRange])
        }
    }

    private static func extractTag(_ tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let textRange = Range(match.range(at: 1), in: xml) else {
            return nil
        }
        return String(xml[textRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private static func resolveURL(base: URL, relative: String) -> String {
        let trimmed = relative.trimmingCharacters(in: .whitespacesAndNewlines)
        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute.absoluteString
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteString ?? trimmed
    }
}

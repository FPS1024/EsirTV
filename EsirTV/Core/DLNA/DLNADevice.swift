//
//  DLNADevice.swift
//  EsirTV
//

import Foundation

/// 局域网 DLNA 渲染设备（电视 / 盒子）
struct DLNADevice: Identifiable, Hashable {
    let id: String
    var name: String
    var location: String
    var controlURL: String
    var serviceType: String

    init(id: String, name: String, location: String, controlURL: String, serviceType: String) {
        self.id = id
        self.name = name
        self.location = location
        self.controlURL = controlURL
        self.serviceType = serviceType
    }
}

//
//  LocalNetworkPermission.swift
//  EsirTV
//
//  iOS 14+ 须通过 Bonjour 浏览或访问局域网 IP 才会弹出「本地网络」授权框。
//

import Foundation
import Network

enum LocalNetworkPermission {
    /// 在 SSDP 发现前调用，尽量触发系统本地网络权限弹窗。
    static func requestAccess() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await browseBonjour() }
            group.addTask { await probeLocalSubnet() }
        }
    }

    private static func browseBonjour() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let browser = NWBrowser(
                for: .bonjour(type: "_http._tcp", domain: nil),
                using: .udp
            )
            let queue = DispatchQueue(label: "esirtv.localnetwork.bonjour")
            var finished = false
            let finish: () -> Void = {
                queue.async {
                    guard !finished else { return }
                    finished = true
                    browser.cancel()
                    continuation.resume()
                }
            }

            browser.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    finish()
                default:
                    break
                }
            }
            browser.browseResultsChangedHandler = { _, _ in
                finish()
            }
            browser.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 2.5, execute: finish)
        }
    }

    private static func probeLocalSubnet() async {
        guard let target = LANInterfaceEnumerator.primaryGatewayHint
            ?? LANInterfaceEnumerator.activeIPv4Interfaces().first?.broadcast else {
            return
        }
        guard let port = NWEndpoint.Port(rawValue: 1900) else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let host = NWEndpoint.Host(target)
            let connection = NWConnection(host: host, port: port, using: .udp)
            let queue = DispatchQueue(label: "esirtv.localnetwork.probe")
            var finished = false
            let finish: () -> Void = {
                queue.async {
                    guard !finished else { return }
                    finished = true
                    connection.cancel()
                    continuation.resume()
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled:
                    finish()
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.15) {
                connection.send(
                    content: Data([0x00]),
                    completion: .contentProcessed { _ in finish() }
                )
            }
            queue.asyncAfter(deadline: .now() + 1.5, execute: finish)
        }
    }
}

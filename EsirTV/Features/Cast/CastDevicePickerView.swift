//
//  CastDevicePickerView.swift
//  EsirTV
//

import SwiftUI

struct CastDevicePickerView: View {
    let mediaURL: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dlna = DLNAManager.shared
    @State private var castingDeviceID: String?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            Group {
                if dlna.isDiscovering && dlna.devices.isEmpty {
                    ProgressView("正在搜索局域网设备…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if dlna.devices.isEmpty {
                    emptyState
                } else {
                    deviceList
                }
            }
            .navigationTitle("投屏到电视")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await dlna.discoverDevices() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(dlna.isDiscovering)
                }
            }
            .task {
                await dlna.discoverDevices()
            }
            .alert("提示", isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } }
            )) {
                Button("好") { toast = nil }
            } message: {
                Text(toast ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(dlna.lastError ?? "未发现设备")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重新搜索") {
                Task { await dlna.discoverDevices() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var deviceList: some View {
        List(dlna.devices) { device in
            Button {
                cast(to: device)
            } label: {
                HStack {
                    Image(systemName: "tv.fill")
                        .foregroundStyle(.tint)
                    Text(device.name)
                    Spacer()
                    if castingDeviceID == device.id {
                        ProgressView()
                    }
                }
            }
            .disabled(castingDeviceID != nil)
        }
    }

    private func cast(to device: DLNADevice) {
        castingDeviceID = device.id
        Task {
            do {
                try await dlna.cast(mediaURL: mediaURL, title: title, to: device)
                toast = "已发送到「\(device.name)」"
                try? await Task.sleep(nanoseconds: 800_000_000)
                dismiss()
            } catch {
                toast = error.localizedDescription
            }
            castingDeviceID = nil
        }
    }
}

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
    @State private var manualIP = ""

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
            .safeAreaInset(edge: .bottom) {
                manualSection
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

    private var manualSection: some View {
        VStack(spacing: 10) {
            Text("未搜到设备？输入电视 IP（设置 → 网络 → 本机 IP）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                TextField("例如 192.168.1.100", text: $manualIP)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("添加") {
                    addManualDevice()
                }
                .buttonStyle(.borderedProminent)
                .disabled(manualIP.trimmingCharacters(in: .whitespaces).isEmpty || dlna.isDiscovering)
            }
        }
        .padding()
        .background(.bar)
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "tv")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(dlna.lastError ?? "未发现设备")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Button("重新搜索") {
                    Task { await dlna.discoverDevices() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private var deviceList: some View {
        List(dlna.devices) { device in
            Button {
                cast(to: device)
            } label: {
                HStack {
                    Image(systemName: "tv.fill")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                        Text(device.location)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if castingDeviceID == device.id {
                        ProgressView()
                    }
                }
            }
            .disabled(castingDeviceID != nil)
        }
    }

    private func addManualDevice() {
        let ip = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok = await dlna.addManualDevice(ip: ip)
            if ok {
                toast = "已添加设备"
                manualIP = ""
            }
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

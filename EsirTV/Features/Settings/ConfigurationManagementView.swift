//
//  ConfigurationManagementView.swift
//  EsirTV
//

import SwiftUI

struct ConfigurationManagementView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @State private var inputURL = ""
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var isSaving = false

    var body: some View {
        List {
            Section {
                TextField("TVBox 订阅配置链接", text: $inputURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    Task { await saveConfig() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("保存并加载站点")
                    }
                }
                .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                Button {
                    Task { await testConfig() }
                } label: {
                    if isTesting {
                        ProgressView()
                    } else {
                        Text("测试链接")
                    }
                }
                .disabled(inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)
            } header: {
                Text("订阅配置")
            } footer: {
                Text("填入 TVBox 配置 JSON 地址，解析后可获取约 20+ 个影视站点，主页右上角可切换站点。")
            }

            if let testResult {
                Section("测试结果") {
                    Text(testResult)
                        .foregroundColor(testResult.contains("成功") ? .green : .red)
                }
            }

            Section {
                if configStore.isLoading {
                    HStack {
                        ProgressView()
                        Text("正在解析站点…")
                    }
                } else if let error = configStore.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                } else if configStore.sites.isEmpty {
                    Text("暂无站点，请先保存配置")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(configStore.sites) { site in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(site.name)
                                    .font(.body.weight(.medium))
                                Text(site.api)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if configStore.selectedSiteKey == site.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            configStore.selectSite(site)
                        }
                    }
                }
            } header: {
                Text("已解析站点（\(configStore.sites.count)）")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已安装 App Build：\(appBuildNumber)")
                    if !configStore.configURL.isEmpty {
                        Text("当前配置：\(configStore.configURL)")
                    }
                    Text("若提示 ATS 错误，请确认 Build ≥ 6 并删除旧版后重装")
                }
                .font(.caption2)
            }
        }
        .navigationTitle("配置管理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            inputURL = configStore.configURL
        }
    }

    private func saveConfig() async {
        isSaving = true
        defer { isSaving = false }

        configStore.saveConfigURL(inputURL)
        await configStore.loadSites(force: true)
        testResult = configStore.errorMessage == nil
            ? "保存成功，已解析 \(configStore.sites.count) 个站点"
            : configStore.errorMessage
    }

    private var appBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    private func testConfig() async {
        isTesting = true
        defer { isTesting = false }

        let result = await configStore.testConfigURL(inputURL)
        testResult = result.success
            ? "测试成功，共 \(result.siteCount) 个站点"
            : "测试失败：\(result.message)"
    }
}

#Preview {
    NavigationStack {
        ConfigurationManagementView()
    }
    .environmentObject(ConfigStore())
}

//
//  AboutView.swift
//  EsirTV
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                        .padding(.top, 8)

                    Text("EsirTV")
                        .font(.title2.bold())

                    Text("版本 \(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("说明") {
                LabeledContent("平台", value: "iPhone & iPad")
                LabeledContent("框架", value: "SwiftUI")
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

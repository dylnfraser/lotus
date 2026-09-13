//
//  AboutSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct AboutSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.userAgentMode") private var userAgentMode: String = "safari"
    @AppStorage("lotus.browser.customUserAgentString") private var customUserAgentString: String = ""

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(
                title: "Identity & Networking",
//                footer: "Configuring a custom User-Agent affects how web servers identify Lotus."
            ) {
                UserAgentSettingsRow(userAgentMode: $userAgentMode, customUserAgentString: $customUserAgentString)
            }

            SettingsSectionCard(title: "Data Reset") {
                ClearDataSettingsRow(browserState: browserState)
            }
        }
    }
}

// MARK: - Rows

private struct UserAgentSettingsRow: View {
    @Binding var userAgentMode: String
    @Binding var customUserAgentString: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            SettingsPickerRow(
                systemImage: "network",
                title: "User Agent",
                subtitle: "Browser identity identifier sent to web servers",
                selection: $userAgentMode,
                options: [
                    ("safari", "Safari / WebKit (Default)"),
                    ("chrome", "Google Chrome"),
                    ("custom", "Custom")
                ],
                pickerWidth: 190
            )

            if userAgentMode == "custom" {
                SettingsDivider(leadingInset: 14)

                HStack(spacing: 8) {
                    SettingsInputField(
                        placeholder: "Enter custom User-Agent string…",
                        text: $customUserAgentString
                    )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct ClearDataSettingsRow: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? Color(nsColor: .systemRed).opacity(0.85) : Color(nsColor: .systemRed))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clear all data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text("Caches, history, download history, logins, cookies, and website data")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            LotusSettingsButton(
                title: "Clear All Data…",
                systemImage: "trash",
                isDestructive: true
            ) {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.84)) {
                    browserState.isClearAllDataConfirmationPresented = true
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

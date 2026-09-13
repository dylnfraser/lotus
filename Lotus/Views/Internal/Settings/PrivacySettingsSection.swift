//
//  PrivacySettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct PrivacySettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @ObservedObject var contentBlocker: ContentBlockerService

    private var historyCount: Int {
        browserState.historyEntries.count
    }

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "Browsing History & Site Data") {
                SettingsButtonRow(
                    systemImage: "clock",
                    title: "Browsing history",
                    subtitle: historyCount == 0 ? "No visited pages recorded" : "\(historyCount) visited page\(historyCount == 1 ? "" : "s")",
                    buttonTitle: "Open History"
                ) {
                    browserState.loadURL(.lotusHistory, in: tabId)
                }
                SettingsDivider()
                SettingsButtonRow(
                    systemImage: "server.rack",
                    title: "Website data & cookies",
                    subtitle: "Inspect and delete cookies, caches, and local storage per site",
                    buttonTitle: "Open Website Data"
                ) {
                    browserState.loadURL(.lotusWebsiteData, in: tabId)
                }
            }

            SettingsSectionCard(
                title: "Privacy & Security Options"
            ) {
                SettingsToggleRow(
                    systemImage: "lock.shield",
                    title: "Strict HTTPS (HTTPS-Only Mode)",
                    subtitle: "Automatically upgrades insecure http:// connections to https://",
                    isOn: $contentBlocker.httpsOnlyModeEnabled
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "hand.raised.slash",
                    title: "Send “Do Not Track” & Global Privacy Control (GPC)",
                    subtitle: "Sends DNT: 1 and Sec-GPC: 1 headers with outgoing web requests",
                    isOn: $contentBlocker.dntEnabled
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "sparkles",
                    title: "Copy clean URLs (strip tracking parameters)",
                    subtitle: "Automatically removes UTM, Facebook, Google, and tracking tags when copying links (⇧⌘C)",
                    isOn: $contentBlocker.copyCleanURLAutomatically
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Clear data on quit",
                    subtitle: "Wipes cookies, caches, history, and downloads when Lotus closes",
                    isOn: $contentBlocker.clearDataOnQuit
                )
            }
        }
    }
}

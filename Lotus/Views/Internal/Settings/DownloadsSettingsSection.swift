//
//  DownloadsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct DownloadsSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @AppStorage("lotus.browser.tidyDownloadsEnabled") private var tidyDownloadsEnabled: Bool = true

    private var downloadCount: Int {
        browserState.downloads.count
    }

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(
                title: "Download Location & Tidy"
            ) {
                SettingsButtonRow(
                    systemImage: "folder",
                    title: "Download location",
                    subtitle: browserState.downloadDirectory.lastPathComponent,
                    buttonTitle: "Change…"
                ) {
                    browserState.chooseDownloadLocation()
                }
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "wand.and.stars",
                    title: "Tidy downloads",
                    subtitle: "Automatically cleans up messy filenames, UUIDs, and URL hashes",
                    isOn: $tidyDownloadsEnabled
                )
                SettingsDivider()
                SettingsButtonRow(
                    systemImage: "arrow.down.circle",
                    title: "Download history",
                    subtitle: downloadCount == 0 ? "No download records" : "\(downloadCount) file\(downloadCount == 1 ? "" : "s") downloaded",
                    buttonTitle: "Open Downloads"
                ) {
                    browserState.loadURL(.lotusDownloads, in: tabId)
                }
            }
        }
    }
}

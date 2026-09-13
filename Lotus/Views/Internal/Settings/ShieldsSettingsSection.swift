//
//  ShieldsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct ShieldsSettingsSection: View {
    @ObservedObject var contentBlocker: ContentBlockerService

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(
                title: "Content & Tracker Blocking"
            ) {
                SettingsToggleRow(
                    systemImage: "shield.checkered",
                    title: "Block ads & trackers",
                    subtitle: "Blocks known trackers, tracking pixels, telemetry, and banner ads",
                    isOn: $contentBlocker.isAdBlockingEnabled
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "cross.case",
                    title: "Block tracking scripts",
                    subtitle: "Blocks analytics telemetry scripts and third-party event trackers",
                    isOn: $contentBlocker.blockTrackersEnabled,
                    isDisabled: !contentBlocker.isAdBlockingEnabled
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "eye.slash",
                    title: "Hide cosmetic placeholders",
                    subtitle: "Collapses and cleans empty whitespace left behind by blocked banner slots",
                    isOn: $contentBlocker.blockCosmeticElementsEnabled,
                    isDisabled: !contentBlocker.isAdBlockingEnabled
                )
            }

            SettingsSectionCard(
                title: "Fingerprint & Canvas Defense"
            ) {
                SettingsToggleRow(
                    systemImage: "theatermasks",
                    title: "Fingerprint protection",
                    subtitle: "Spoofs Canvas, WebGL, and AudioContext to block hardware profiling",
                    isOn: $contentBlocker.fingerprintProtectionEnabled,
                    isDisabled: !contentBlocker.isAdBlockingEnabled
                )
                SettingsDivider()
                SettingsPickerRow(
                    systemImage: "square.fill.and.line.vertical.and.square.fill",
                    title: "Canvas defense mode",
                    subtitle: contentBlocker.strictCanvasBlockEnabled ? "Strictly blocks canvas pixel readouts" : "Injects random noise jitter into canvas extraction",
                    selection: $contentBlocker.strictCanvasBlockEnabled,
                    options: [
                        (false, "Noise Jitter (Recommended)"),
                        (true, "Strict Block")
                    ],
                    pickerWidth: 200,
                    isDisabled: !contentBlocker.fingerprintProtectionEnabled || !contentBlocker.isAdBlockingEnabled
                )
            }

            SettingsSectionCard(title: "Exceptions & Site Rules") {
                ShieldsStrictPopupBlockedSettingsRow(contentBlocker: contentBlocker)
                SettingsDivider()
                ShieldsAllowlistSettingsRow(contentBlocker: contentBlocker)
            }

            ShieldsZappedElementsSettingsCard()
        }
    }
}

// MARK: - Rows

private struct ShieldsStrictPopupBlockedSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var blockedList: [String] {
        contentBlocker.strictPopupBlockedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Strict popup & link blocklist")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(blockedList.isEmpty ? "No sites strictly blocked" : "\(blockedList.count) site\(blockedList.count == 1 ? "" : "s") blocking all popups/links")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    SettingsDivider(leadingInset: 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        SettingsInputField(
                            placeholder: "Add website domain (e.g. example.com)",
                            text: $newDomainInput,
                            onCommit: {
                                if !newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    addDomain()
                                }
                            }
                        )

                        LotusSettingsButton(
                            title: "Add",
                            systemImage: "plus",
                            isDisabled: newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            addDomain()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Blocklist items
                    if blockedList.isEmpty {
                        Text("No websites are currently blocking all popups/links.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(blockedList, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.setStrictPopupBlocking(for: domain, enabled: false)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove strict popup block")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.setStrictPopupBlocking(for: clean, enabled: true)
        newDomainInput = ""
    }
}

private struct ShieldsAllowlistSettingsRow: View {
    @ObservedObject var contentBlocker: ContentBlockerService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var newDomainInput: String = ""

    private var allowlist: [String] {
        contentBlocker.allowlistedDomains.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Whitelisted websites")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(allowlist.isEmpty ? "No sites whitelisted" : "\(allowlist.count) site\(allowlist.count == 1 ? "" : "s") allowed")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)

            if isExpanded {
                VStack(spacing: 8) {
                    SettingsDivider(leadingInset: 14)

                    // Add new domain input
                    HStack(spacing: 8) {
                        SettingsInputField(
                            placeholder: "Add website domain (e.g. example.com)",
                            text: $newDomainInput,
                            onCommit: {
                                if !newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    addDomain()
                                }
                            }
                        )

                        LotusSettingsButton(
                            title: "Add",
                            systemImage: "plus",
                            isDisabled: newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            addDomain()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    // Allowlist items
                    if allowlist.isEmpty {
                        Text("No websites have shields disabled.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(allowlist, id: \.self) { domain in
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                    Spacer()

                                    Button {
                                        contentBlocker.removeAllowlistDomain(domain)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove from whitelist")
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
            }
        }
    }

    private func addDomain() {
        let clean = newDomainInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        contentBlocker.addAllowlistDomain(clean)
        newDomainInput = ""
    }
}

// MARK: - Zapped Elements Card

private struct ShieldsZappedElementsSettingsCard: View {
    @ObservedObject private var zapStore = SiteZapStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = true

    var body: some View {
        SettingsSectionCard(title: "Zapped Elements (Boosts)", systemImage: "wand.and.stars") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.shield")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Custom blocked DOM elements")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                        Text("Elements removed using the point-and-click Zap tool (⌘⌥Z)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                    }

                    Spacer()

                    if zapStore.totalZapCount > 0 {
                        Button("Clear All") {
                            zapStore.clearAll()
                        }
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)

                SettingsDivider()

                if zapStore.allDomains.isEmpty {
                    Text("No elements have been zapped yet. Use ⌘⌥Z on any page to zap unwanted elements.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    VStack(spacing: 12) {
                        ForEach(zapStore.allDomains, id: \.self) { domain in
                            let elements = zapStore.zappedElements(for: domain)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(domain)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : Color(nsColor: .labelColor))

                                    Text("(\(elements.count))")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)

                                    Spacer()

                                    Button {
                                        zapStore.clearZaps(for: domain)
                                    } label: {
                                        Text("Clear Site")
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }

                                VStack(spacing: 4) {
                                    ForEach(elements) { zap in
                                        HStack(spacing: 8) {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(zap.elementSummary)
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.88) : .primary)
                                                    .lineLimit(1)

                                                Text(zap.selector)
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer()

                                            Button {
                                                zapStore.removeZap(zap)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Color(nsColor: .systemRed).opacity(0.75))
                                                    .padding(3)
                                            }
                                            .buttonStyle(.plain)
                                            .help("Restore element")
                                        }
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

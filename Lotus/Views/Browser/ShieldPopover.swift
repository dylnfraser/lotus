//
//  ShieldPopover.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import SwiftUI

/// Popover displayed when clicking the Shield button in the toolbar,
/// allowing per-site content blocking control and showing privacy protection info.
struct ShieldPopover: View {
    @ObservedObject var browserState: BrowserState
    let tabId: UUID
    let onDismiss: () -> Void

    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @Environment(\.colorScheme) private var colorScheme

    private var currentURL: URL? {
        browserState.url(for: tabId)
    }

    private var domainName: String {
        guard let url = currentURL, let host = DomainNormalizer.normalize(url: url) else {
            return "This Website"
        }
        return host
    }

    private var isShieldActive: Bool {
        contentBlocker.isShieldActive(for: currentURL)
    }

    private var isStrictPopupBlocking: Bool {
        contentBlocker.isStrictPopupBlockingActive(for: currentURL)
    }

    private var isFingerprintProtection: Bool {
        contentBlocker.isFingerprintProtectionActive(for: currentURL)
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.50) : Color(nsColor: .secondaryLabelColor)
    }

    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"

    private var currentAccentColor: Color {
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    private var activeShieldColor: Color {
        Color(nsColor: browserState.detectedAccentNSColor(for: tabId))
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: isShieldActive ? "shield.fill" : "shield.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isShieldActive ? activeShieldColor : foregroundSecondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Shields")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(foregroundPrimary)

                    Text(domainName)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))

            // Main Protection Toggle Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shields on this site")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)

                        Text(isShieldActive ? "Blocking ads and trackers" : "Protection paused")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(isShieldActive ? Color.accentColor : foregroundSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isShieldActive },
                        set: { _ in
                            browserState.toggleShield(for: tabId)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )

                // Strict Popups & Links Toggle Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Block popups & links")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)

                        Text(isStrictPopupBlocking ? "Popups and new tabs blocked" : "Normal link & popup behavior")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(isStrictPopupBlocking ? Color.accentColor : foregroundSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isStrictPopupBlocking },
                        set: { _ in
                            browserState.toggleStrictPopupBlocking(for: tabId)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )

                // Advanced Fingerprint Protection Toggle Card
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fingerprint protection")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)

                        Text(isFingerprintProtection ? "Canvas, WebGL & metrics masked" : "Standard device reporting")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(isFingerprintProtection ? Color.accentColor : foregroundSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isFingerprintProtection },
                        set: { _ in
                            browserState.toggleFingerprintProtection(for: tabId)
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!isShieldActive || !contentBlocker.fingerprintProtectionEnabled)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )
                .opacity((isShieldActive && contentBlocker.fingerprintProtectionEnabled) ? 1.0 : 0.5)

                // Protection Summary Badges
                VStack(spacing: 6) {
                    protectionFeatureRow(
                        icon: "hand.raised.fill",
                        title: "Trackers & Analytics",
                        status: isShieldActive && contentBlocker.blockTrackersEnabled ? "Blocked" : "Allowed"
                    )

                    protectionFeatureRow(
                        icon: "nosign",
                        title: "Advertisements",
                        status: isShieldActive && contentBlocker.isAdBlockingEnabled ? "Blocked" : "Allowed"
                    )

                    protectionFeatureRow(
                        icon: "link.badge.plus",
                        title: "Popups & Link Traps",
                        status: isStrictPopupBlocking ? "Blocked" : (isShieldActive ? "Filtered" : "Allowed")
                    )

                    protectionFeatureRow(
                        icon: "eye.slash.fill",
                        title: "Cosmetic Placeholders",
                        status: isShieldActive && contentBlocker.blockCosmeticElementsEnabled ? "Hidden" : "Shown"
                    )

                    protectionFeatureRow(
                        icon: "theatermasks.fill",
                        title: "Fingerprint Obscuration",
                        status: isFingerprintProtection ? "Masked" : "Default"
                    )
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)

                // Zap Element Tool (Visual DOM Blocker)
                Button {
                    onDismiss()
                    browserState.startZapMode(for: tabId)
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(currentAccentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                                .frame(width: 30, height: 30)

                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(currentAccentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zap Element on Page")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(foregroundPrimary)

                            Text("Click to permanently block any element")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(foregroundSecondary)
                        }

                        Spacer()

                        Text("⌘⌥Z")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(foregroundSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(cardStroke, lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))

            // Footer
            Button {
                onDismiss()
                browserState.addTabBelow(title: "Settings", url: .lotusSettings, select: true)
            } label: {
                HStack(spacing: 6) {
                    Text("Shields & Privacy Settings…")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(Color.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 300)
        .background(
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
        )
    }

    private func protectionFeatureRow(icon: String, title: String, status: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(status == "Blocked" || status == "Hidden" ? Color.accentColor : foregroundSecondary.opacity(0.6))
                .frame(width: 14)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(foregroundPrimary.opacity(0.9))

            Spacer()

            Text(status)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(status == "Blocked" || status == "Hidden" ? foregroundSecondary : foregroundSecondary.opacity(0.5))
        }
    }
}

//
//  ZapHUDView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI

/// Floating HUD displayed at the bottom of the viewport while visual Zap mode is active.
struct ZapHUDView: View {
    @ObservedObject var browserState: BrowserState
    let tabId: UUID
    @ObservedObject private var zapStore = SiteZapStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var isManagerPopoverPresented: Bool = false

    private var domainName: String {
        guard let url = browserState.url(for: tabId), let host = url.host else {
            return "this site"
        }
        return host
    }

    private var domainZaps: [ZappedElement] {
        zapStore.zappedElements(for: domainName)
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.65) : Color(nsColor: .secondaryLabelColor)
    }

    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"

    private var currentAccentColor: Color {
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon & Mode Indicator
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(currentAccentColor.opacity(colorScheme == .dark ? 0.25 : 0.15))
                        .frame(width: 28, height: 28)

                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(currentAccentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Zap Element")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(foregroundPrimary)

                        Text("Active")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(currentAccentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(currentAccentColor.opacity(colorScheme == .dark ? 0.20 : 0.12))
                            )
                    }

                    Text("Click any element to block it forever")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }
            }

            Divider()
                .frame(height: 20)
                .opacity(0.3)

            // Actions
            HStack(spacing: 8) {
                // Undo Button
                if let lastZap = browserState.lastZappedElement {
                    Button {
                        browserState.undoLastZap(for: tabId)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Undo")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Zapped Elements Manager Popover Button
                Button {
                    isManagerPopoverPresented.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11, weight: .semibold))
                        Text(domainZaps.isEmpty ? "Zaps" : "Zaps (\(domainZaps.count))")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(domainZaps.isEmpty ? foregroundSecondary : foregroundPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isManagerPopoverPresented, arrowEdge: .top) {
                    zappedElementsManagerPopover
                }

                // Done / Exit Button
                Button {
                    browserState.stopZapMode(for: tabId)
                } label: {
                    HStack(spacing: 4) {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold))
                        Text("⎋")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(currentAccentColor)
                    )
                }
                .buttonStyle(.plain)
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: browserState.lastZappedElement)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                if accentColorKey != "white" {
                    currentAccentColor
                        .opacity(colorScheme == .dark ? 0.18 : 0.32)
                }
                (colorScheme == .dark ? Color.black.opacity(0.35) : Color(nsColor: .windowBackgroundColor).opacity(0.75))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14),
            radius: 14,
            x: 0,
            y: 4
        )
    }

    // MARK: - Zapped Elements Popover

    private var zappedElementsManagerPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zapped on \(domainName)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(foregroundPrimary)

                Spacer()

                if !domainZaps.isEmpty {
                    Button("Clear All") {
                        zapStore.clearZaps(for: domainName)
                        browserState.applyZapRules(for: tabId)
                    }
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                    .buttonStyle(.plain)
                }
            }

            Divider()

            if domainZaps.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundColor(foregroundSecondary.opacity(0.5))
                        .padding(.top, 6)

                    Text("No elements zapped on this site yet.")
                        .font(.system(size: 11))
                        .foregroundColor(foregroundSecondary)
                        .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(domainZaps) { zap in
                            HStack(spacing: 8) {
                                 VStack(alignment: .leading, spacing: 2) {
                                    Text(zap.elementSummary)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(foregroundPrimary)
                                        .lineLimit(1)

                                    Text(zap.selector)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(foregroundSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button {
                                    browserState.removeZappedElement(zap, tabId: tabId)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(nsColor: .systemRed).opacity(0.8))
                                        .padding(4)
                                }
                                .buttonStyle(.plain)
                                .help("Restore this element")
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                            )
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

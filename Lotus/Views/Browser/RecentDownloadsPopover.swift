//
//  RecentDownloadsPopover.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// A compact Safari-style popover displaying recent downloads, real-time progress,
/// Finder reveal actions, and a "Clear" option.
struct RecentDownloadsPopover: View {
    @ObservedObject var browserState: BrowserState
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItemId: UUID? = nil

    private var recentDownloads: [DownloadItem] {
        Array(browserState.activeProfileDownloads.prefix(8))
    }

    private var hasCompletedDownloads: Bool {
        browserState.activeProfileDownloads.contains(where: { $0.state != .downloading })
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.50) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("Downloads")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(foregroundPrimary)

                Spacer()

                Button {
                    browserState.clearCompletedDownloads(for: browserState.currentProfileId)
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(hasCompletedDownloads ? Color.accentColor : foregroundSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!hasCompletedDownloads)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))

            // Download items list / Empty state
            if recentDownloads.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(foregroundSecondary.opacity(0.5))

                    Text("No Recent Downloads")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(recentDownloads) { item in
                            downloadRow(item)

                            if item.id != recentDownloads.last?.id {
                                Divider()
                                    .overlay(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
                                    .padding(.leading, 46)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()
                .overlay(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))

            // Footer
            Button {
                onDismiss()
                browserState.addTabBelow(title: "Downloads", url: .lotusDownloads, select: true)
            } label: {
                HStack(spacing: 6) {
                    Text("Show All Downloads…")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(hasCompletedDownloads ? Color.accentColor : foregroundSecondary.opacity(0.5))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 320)
        .background(
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
        )
    }

    // MARK: - Row

    @ViewBuilder
    private func downloadRow(_ item: DownloadItem) -> some View {
        let isHovered = hoveredItemId == item.id

        Button {
            item.openFile()
        } label: {
            HStack(spacing: 11) {
                // File icon
                Image(systemName: item.systemIconName)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(item.state == .failed ? Color(nsColor: .systemRed).opacity(0.85) : Color.accentColor)
                    .frame(width: 24, height: 24)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.filename)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        Text(item.formattedSize)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(foregroundSecondary)

                        if item.state == .downloading {
                            if let speed = item.formattedSpeed {
                                Text("• \(speed)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            } else {
                                Text("• Downloading…")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.accentColor)
                            }

                            if let eta = item.formattedETA {
                                Text("(\(eta))")
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(foregroundSecondary)
                            }
                        } else if item.state == .paused {
                            Text("• Paused")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(nsColor: .systemOrange).opacity(0.9))
                        } else if item.state == .failed {
                            Text("• Failed")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                        } else if item.state == .cancelled {
                            Text("• Cancelled")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(foregroundSecondary)
                        }
                    }

                    if item.state == .downloading {
                        ProgressView(value: item.progressFraction)
                            .progressViewStyle(.linear)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                // Action buttons
                if item.state == .downloading {
                    Button {
                        browserState.pauseDownload(id: item.id)
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(foregroundSecondary)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Pause Download")

                    Button {
                        browserState.cancelDownload(id: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(foregroundSecondary)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Cancel Download")
                } else if item.state == .paused {
                    Button {
                        browserState.resumeDownload(id: item.id)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color.accentColor)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Resume Download")

                    Button {
                        browserState.cancelDownload(id: item.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(foregroundSecondary)
                            .padding(5)
                            .background(
                                Circle()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Cancel Download")
                } else if item.state == .failed || item.state == .cancelled {
                    Button {
                        browserState.retryDownload(id: item.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.accentColor)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Retry Download")
                } else {
                    Button {
                        item.revealInFinder()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(foregroundSecondary)
                            .padding(5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isHovered
                    ? (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            guard item.fileExists else { return NSItemProvider() }
            let provider = NSItemProvider(contentsOf: item.destinationURL) ?? NSItemProvider()
            provider.suggestedName = item.filename
            return provider
        }
        .onHover { hovering in
            hoveredItemId = hovering ? item.id : (hoveredItemId == item.id ? nil : hoveredItemId)
        }
        .contextMenu {
            if item.state == .downloading {
                Button("Pause Download") {
                    browserState.pauseDownload(id: item.id)
                }
                Button("Cancel Download", role: .destructive) {
                    browserState.cancelDownload(id: item.id)
                }
                Divider()
            } else if item.state == .paused {
                Button("Resume Download") {
                    browserState.resumeDownload(id: item.id)
                }
                Button("Cancel Download", role: .destructive) {
                    browserState.cancelDownload(id: item.id)
                }
                Divider()
            } else if item.state == .failed || item.state == .cancelled {
                Button("Retry Download") {
                    browserState.retryDownload(id: item.id)
                }
                Divider()
            }

            Button("Open File") {
                item.openFile()
            }
            .disabled(!item.fileExists)

            Button("Show in Finder") {
                item.revealInFinder()
            }

            Divider()

            Button("Copy Download Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.originalURL.absoluteString, forType: .string)
            }

            Divider()

            Button("Delete from History", role: .destructive) {
                browserState.removeDownload(id: item.id)
            }
        }
    }
}

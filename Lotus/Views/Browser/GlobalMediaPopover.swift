//
//  GlobalMediaPopover.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

struct GlobalMediaPopover: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme

    private var activeMediaTabIds: [UUID] {
        browserState.mediaTabs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Media Playback", systemImage: "play.tv")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(activeMediaTabIds.count) Active")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 4)

            Divider()

            if activeMediaTabIds.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("No audio or video playing")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(activeMediaTabIds, id: \.self) { tabId in
                            mediaCard(for: tabId)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func mediaCard(for tabId: UUID) -> some View {
        let tab = browserState.tab(for: tabId)
        let mediaState = browserState.tabMediaStates[tabId]
        let isPlaying = mediaState?.isPlaying ?? false
        let isMuted = mediaState?.isMuted ?? false

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let host = tab?.url?.host {
                    Text(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text(tab?.title ?? "Web Page")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    browserState.selectTab(tabId)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Jump to Tab")
            }

            if let title = mediaState?.mediaTitle, !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 12) {
                // Play / Pause
                Button {
                    browserState.togglePlayPauseMedia(for: tabId)
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Mute / Unmute
                Button {
                    browserState.toggleMuteTab(id: tabId)
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(isMuted ? .orange : .primary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Picture-in-Picture
                if mediaState?.hasVideo == true {
                    Button {
                        browserState.triggerPictureInPicture(for: tabId)
                    } label: {
                        Image(systemName: "pip.enter")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Picture in Picture")
                }

                Spacer()
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

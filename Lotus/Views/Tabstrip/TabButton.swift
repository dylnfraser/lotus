//
//  TabButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    var isMultiSelected: Bool = false
    var isSplitMember: Bool = false
    var isDragging: Bool = false
    var isDraggingAnyTab: Bool = false
    var isThemeLight: Bool = false
    var activeTabBackgroundColor: Color = Color(nsColor: .windowBackgroundColor)
    var namespace: Namespace.ID? = nil
    let sidebarWidth: CGFloat
    var customWidth: CGFloat? = nil
    var isSplit: Bool = false
    var isRenaming: Bool = false
    var isPlayingAudio: Bool = false
    var isMuted: Bool = false
    var onToggleMute: () -> Void = {}
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovered: Bool = false
    @State private var draftTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    @AppStorage("lotus.browser.smoothTabSwitchAnimation") private var smoothTabSwitchAnimation: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

    private var isInternalPage: Bool {
        tab.url?.isLotusPage == true
    }

    /// The sidebar sits on a translucent vibrancy background.
    /// In dark mode text is white; in light mode text is dark.
    private var sidebarForeground: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var sidebarForegroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.60) : Color(nsColor: .secondaryLabelColor)
    }

    private var isHighlighted: Bool {
        isSelected || isSplitMember
    }

    private var foregroundPrimary: Color {
        sidebarForeground
    }

    private var foregroundSecondary: Color {
        sidebarForegroundSecondary
    }

    private var selectedForegroundPrimary: Color {
        isThemeLight ? (colorScheme == .dark ? .black : Color(nsColor: .labelColor)) : .white
    }

    private var selectedForegroundSecondary: Color {
        isThemeLight ? (colorScheme == .dark ? Color.black.opacity(0.60) : Color(nsColor: .secondaryLabelColor)) : Color.white.opacity(0.60)
    }

    var body: some View {
        let targetWidth = customWidth ?? max(0, sidebarWidth - 16)

        HStack(spacing: isSplit ? 6 : 8) {
            ZStack {
                faviconView
                    .opacity((isMuted || tab.isMuted || (isPlayingAudio && effectiveHovered)) ? 0 : 1)

                if isMuted || tab.isMuted {
                    Button(action: onToggleMute) {
                        Image(systemName: "speaker.slash.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Unmute Tab")
                } else if isPlayingAudio && effectiveHovered {
                    Button(action: onToggleMute) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isSelected ? selectedForegroundPrimary : sidebarForeground)
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .help("Mute Tab")
                }
            }
            .frame(width: 16, height: 16, alignment: .center)

            if isRenaming {
                TextField("Tab Title", text: $draftTitle)
                    .font(.system(size: isSplit ? 12 : 13, weight: .medium))
                    .foregroundColor(isSelected ? selectedForegroundPrimary : sidebarForeground)
                    .textFieldStyle(.plain)
                    .focused($isTitleFocused)
                    .onSubmit {
                        onCommitRename(draftTitle)
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                Text(tab.title)
                    .font(.system(size: isSplit ? 12 : 13, weight: .medium))
                    .foregroundColor(isSelected ? selectedForegroundPrimary : (tab.isSnoozed ? sidebarForegroundSecondary : sidebarForeground))
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.16), value: isSelected)
            }

            if tab.isSnoozed && !isSelected {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(sidebarForegroundSecondary.opacity(0.8))
                    .help("Tab is snoozed to save memory (click to wake)")
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? selectedForegroundSecondary : sidebarForegroundSecondary)
                    .animation(.easeInOut(duration: 0.16), value: isSelected)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(effectiveHovered && !isRenaming ? 1 : 0)
            .allowsHitTesting(effectiveHovered && !isRenaming)
        }
        .padding(.horizontal, isSplit ? 6 : 8)
        .frame(width: targetWidth, height: 34, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                    .opacity(!isHighlighted && effectiveHovered ? 1 : 0)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.04))
                    .opacity(isMultiSelected ? 1 : 0)

                if isSelected {
                    if let namespace = namespace, smoothTabSwitchAnimation {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "activeTabHighlight", in: namespace, properties: .frame)
                            .zIndex(10)
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(activeTabBackgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .zIndex(10)
                            .animation(nil, value: activeTabBackgroundColor)
                            .animation(nil, value: isSelected)
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.09), lineWidth: 1)
                .opacity(isMultiSelected ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            if !isRenaming {
                onSelect()
            }
        }
        .onHover { hovering in
            guard !isDraggingAnyTab else {
                isHovered = false
                return
            }
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draftTitle = tab.title
                isTitleFocused = true
                DispatchQueue.main.async {
                    isTitleFocused = true
                }
            }
        }
        .focusable(false)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                removal: .opacity.combined(with: .scale(scale: 0.97))
            )
        )
    }

    @ViewBuilder
    private var faviconView: some View {
        ZStack {
            if isInternalPage {
                Image(systemName: tab.url?.internalPageSystemImage ?? "globe")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(foregroundPrimary.opacity(0.85))
                    .frame(width: 16, height: 16, alignment: .center)
            } else if let faviconURL = tab.faviconURL {
                CachedFaviconView(
                    url: faviconURL,
                    defaultSystemName: "camera.macro",
                    fallbackColor: foregroundSecondary,
                    size: 14
                )
                .frame(width: 16, height: 16, alignment: .center)
            } else {
                defaultGlyph
            }
        }
        .frame(width: 16, height: 16, alignment: .center)
        .contentTransition(.identity)
    }

    private var defaultGlyph: some View {
        Image(systemName: "camera.macro")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foregroundSecondary)
            .frame(width: 16, height: 16, alignment: .center)
            .contentTransition(.identity)
    }
}

//
//  PinnedTabButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import Combine

struct PinnedTabButton: View {
    let tab: TabItem
    let isSelected: Bool
    var isMultiSelected: Bool = false
    var isInSplit: Bool = false
    var isDraggingAnyTab: Bool = false
    var namespace: Namespace.ID? = nil
    var isRenaming: Bool = false
    var isPlayingAudio: Bool = false
    var isMuted: Bool = false
    var onToggleMute: () -> Void = {}
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    var profileAccentColor: Color = .blue
    let onSelect: () -> Void

    @State private var isHovered: Bool = false
    @State private var draftTitle: String = ""
    @FocusState private var isTitleFocused: Bool
    @ObservedObject private var colorExtractor = FaviconColorExtractor.shared
    @AppStorage("lotus.browser.pinnedTabTintingMode") private var pinnedTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.smoothTabSwitchAnimation") private var smoothTabSwitchAnimation: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    private var effectiveHovered: Bool {
        isHovered && !isDraggingAnyTab
    }

    private var dynamicFaviconColors: [Color] {
        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            return []
        }
        if let faviconURL = tab.faviconURL {
            if let extracted = colorExtractor.colors(for: faviconURL) {
                let vibrants = extracted.compactMap { Self.makeVibrant($0) }
                if !vibrants.isEmpty {
                    return vibrants
                }
            }
            if let extracted = colorExtractor.color(for: faviconURL),
               let vibrant = Self.makeVibrant(extracted) {
                return [vibrant]
            }
        }
        return []
    }

    private var dynamicFaviconColor: Color? {
        dynamicFaviconColors.first
    }

    private var adaptiveColor: Color {
        if let dynamic = dynamicFaviconColor {
            return dynamic
        }
        // Fallback for monochrome / plain favicons (black/white/gray depending on light/dark mode)
        return colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.55)
    }

    private var primaryColor: Color {
        switch pinnedTabTintingMode {
        case "neutral":
            return colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.30)
        case "systemAccent":
            if profileAccentColor == FolderColor.grey.color || profileAccentColor == Color(nsColor: .systemGray) {
                return colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.30)
            }
            return profileAccentColor
        default: // "adaptive"
            return adaptiveColor
        }
    }

    @ViewBuilder
    private var cardBackgroundView: some View {
        if isSelected {
            if pinnedTabTintingMode == "adaptive" && !dynamicFaviconColors.isEmpty {
                let colors = dynamicFaviconColors
                if colors.count >= 2 {
                    ZStack {
                        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white

                        LinearGradient(
                            colors: colors.map { $0.opacity(colorScheme == .dark ? 0.26 : 0.16) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                } else if let single = colors.first {
                    ZStack {
                        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white

                        LinearGradient(
                            stops: [
                                .init(color: single.opacity(colorScheme == .dark ? 0.28 : 0.18), location: 0.0),
                                .init(color: single.opacity(colorScheme == .dark ? 0.10 : 0.06), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                } else {
                    colorScheme == .dark ? Color.white.opacity(0.14) : Color.white
                }
            } else if pinnedTabTintingMode == "systemAccent" && profileAccentColor != FolderColor.grey.color && profileAccentColor != Color(nsColor: .systemGray) {
                ZStack {
                    colorScheme == .dark ? Color.white.opacity(0.10) : Color.white

                    LinearGradient(
                        stops: [
                            .init(color: profileAccentColor.opacity(colorScheme == .dark ? 0.26 : 0.16), location: 0.0),
                            .init(color: profileAccentColor.opacity(colorScheme == .dark ? 0.09 : 0.05), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            } else {
                colorScheme == .dark ? Color.white.opacity(0.14) : Color.white
            }
        } else {
            // Unselected pinned tabs (both neutral and unselected adaptive use neutral appearance)
            if colorScheme == .light {
                if pinnedTabTintingMode == "systemAccent" && profileAccentColor != FolderColor.grey.color && profileAccentColor != Color(nsColor: .systemGray) {
                    effectiveHovered ? profileAccentColor.opacity(0.10) : profileAccentColor.opacity(0.05)
                } else {
                    effectiveHovered ? Color.black.opacity(0.08) : Color.black.opacity(0.05)
                }
            } else {
                if pinnedTabTintingMode == "systemAccent" && profileAccentColor != FolderColor.grey.color && profileAccentColor != Color(nsColor: .systemGray) {
                    effectiveHovered ? profileAccentColor.opacity(0.12) : profileAccentColor.opacity(0.06)
                } else {
                    effectiveHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.05)
                }
            }
        }
    }

    private var cardStrokeColor: Color {
        if isSelected {
            return primaryColor
        } else if isInSplit {
            return primaryColor.opacity(0.60)
        } else if effectiveHovered {
            if pinnedTabTintingMode == "systemAccent" && profileAccentColor != FolderColor.grey.color && profileAccentColor != Color(nsColor: .systemGray) {
                return profileAccentColor.opacity(0.40)
            } else {
                // Both "neutral" and unselected "adaptive" have clean neutral styling
                return colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
            }
        } else {
            if pinnedTabTintingMode == "systemAccent" && profileAccentColor != FolderColor.grey.color && profileAccentColor != Color(nsColor: .systemGray) {
                return profileAccentColor.opacity(0.20)
            } else {
                // Both "neutral" and unselected "adaptive" have clean neutral styling
                return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
            }
        }
    }

    private var cardStrokeWidth: CGFloat {
        if isSelected {
            return 2.0
        } else if isInSplit {
            return 1.5
        } else {
            return 1.0
        }
    }

    private var cardShadowColor: Color {
        if isSelected {
            if pinnedTabTintingMode == "neutral" || (pinnedTabTintingMode == "adaptive" && dynamicFaviconColor == nil) || (pinnedTabTintingMode == "systemAccent" && (profileAccentColor == FolderColor.grey.color || profileAccentColor == Color(nsColor: .systemGray))) {
                return Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08)
            } else {
                return primaryColor.opacity(colorScheme == .dark ? 0.35 : 0.22)
            }
        } else {
            return Color.black.opacity(effectiveHovered ? 0.04 : 0.02)
        }
    }

    private var cardShadowRadius: CGFloat {
        isSelected ? 3.5 : (effectiveHovered ? 1.2 : 0.8)
    }

    private var cardShadowY: CGFloat {
        isSelected ? 1.2 : 0.4
    }

    /// Checks if a color is non-plain (not white, gray, black, or washed out) and boosts its saturation if needed.
    static func makeVibrant(_ color: Color) -> Color? {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Filter out gray, monochrome, near-white, or near-black colors
        if s < 0.22 || b < 0.18 || (b > 0.94 && s < 0.32) {
            return nil
        }

        // Boost saturation and brightness for luminous UI presence
        let boostedS = max(s * 1.15, 0.60)
        let boostedB = min(max(b, 0.72), 0.95)
        return Color(nsColor: NSColor(hue: h, saturation: min(boostedS, 1.0), brightness: boostedB, alpha: 1.0))
    }

    var body: some View {
        HStack {
            if isRenaming {
                TextField("Tab Title", text: $draftTitle)
                    .font(.system(size: 12, weight: .medium))
                    .textFieldStyle(.plain)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .focused($isTitleFocused)
                    .onSubmit {
                        onCommitRename(draftTitle)
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                ZStack {
                    faviconView
                        .opacity((isMuted || tab.isMuted || (isPlayingAudio && effectiveHovered)) ? 0 : 1)

                    if isMuted || tab.isMuted {
                        Button(action: onToggleMute) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Unmute Tab")
                    } else if isPlayingAudio && effectiveHovered {
                        Button(action: onToggleMute) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(colorScheme == .dark ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                        .help("Mute Tab")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 38)
        .background(
            cardBackgroundView
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(cardStrokeColor, lineWidth: cardStrokeWidth)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10), lineWidth: 2)
                )
                .opacity(isMultiSelected ? 1 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
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
            withAnimation(.easeInOut(duration: 0.1)) {
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
    }

    @ViewBuilder
    private var faviconView: some View {
        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            Image(systemName: "apple.logo")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        } else if tab.url?.isLotusPage == true {
            Image(systemName: tab.url?.internalPageSystemImage ?? "globe")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : Color(nsColor: .labelColor))
        } else if let faviconURL = tab.faviconURL {
            CachedFaviconView(
                url: faviconURL,
                defaultSystemName: "globe",
                fallbackColor: colorScheme == .dark ? .white.opacity(0.7) : Color(nsColor: .secondaryLabelColor),
                size: 16
            )
            .frame(width: 16, height: 16, alignment: .center)
        } else {
            defaultGlyph
        }
    }

    private var defaultGlyph: some View {
        Image(systemName: "globe")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : Color(nsColor: .secondaryLabelColor))
    }
}

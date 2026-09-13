//
//  BrowserToolbar.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

struct BrowserToolbar: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow

    @State private var urlInputText: String = ""
    @State private var isInputHovered: Bool = false

    @State private var backOffset: CGFloat = 0
    @State private var forwardOffset: CGFloat = 0
    /// True for the remainder of the runloop tick in which the selected tab changed.
    /// Focus gains arriving during that window are spurious SwiftUI field-editor
    /// restorations from the view diff, not user clicks, so they get dropped.
    @State private var isSwitchingTabs: Bool = false
    @Binding var isDownloadsPopoverPresented: Bool
    @State private var isCatchingDownload: Bool = false
    @State private var showDownloadSuccessRing: Bool = false
    @State private var downloadRingScale: CGFloat = 0.85
    @State private var downloadRingOpacity: Double = 0.0
    @State private var isZoomIndicatorVisible: Bool = false
    @State private var isSecurityPopoverPresented: Bool = false
    @State private var isMediaPopoverPresented: Bool = false
    @AppStorage("lotus.browser.centerURLPreview") private var centerURLPreview: Bool = false
    @AppStorage("lotus.browser.toolbarLayout") private var toolbarLayoutRaw: String = ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)

    private var toolbarItems: [ToolbarItemType] {
        ToolbarItemType.parseLayout(from: toolbarLayoutRaw)
    }

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isLoading: Bool {
        browserState.isLoading(for: activeTabId)
    }

    private var theme: BrowserChromeTheme {
        BrowserChromeTheme(browserState: browserState, tabId: activeTabId, colorScheme: colorScheme)
    }

    private var currentURL: URL? {
        browserState.url(for: activeTabId)
    }

    private var currentTab: TabItem? {
        browserState.tab(for: activeTabId)
    }

    private var canGoBack: Bool {
        browserState.canGoBack(for: activeTabId)
    }

    private var canGoForward: Bool {
        browserState.canGoForward(for: activeTabId)
    }

    private var isLeftmostContainer: Bool {
        guard let firstId = browserState.currentTabIds.first else { return true }
        return activeTabId == firstId
    }

    private var currentZoomLevel: CGFloat {
        browserState.zoomLevel(for: activeTabId)
    }

    private var clampedDownloadProgress: CGFloat {
        CGFloat(max(0.08, min(1.0, browserState.overallDownloadProgress)))
    }

    private var hairlineAccentColor: Color {
        if let faviconURL = browserState.tab(for: activeTabId)?.faviconURL,
           let extracted = FaviconColorExtractor.shared.color(for: faviconURL) {
            return extracted
        }
        if let theme = browserState.themeColor(for: activeTabId) {
            return theme
        }
        return Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(toolbarItems, id: \.id) { item in
                toolbarItemView(for: item)
            }

            if !toolbarItems.contains(.addressBar) {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 40)
        .background(theme.backgroundColor)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: toolbarLayoutRaw)
        .onAppear {
            syncInputText()
        }
        .onChange(of: activeTabId) {
            handleTabSwitch()
        }
        .onChange(of: browserState.url(for: activeTabId)) {
            syncInputText()
        }
        .onChange(of: browserState.pageLoadErrors[activeTabId]) {
            syncInputText()
        }
        .onChange(of: currentZoomLevel) { _, newZoomLevel in
            if newZoomLevel != 1.0 {
                isZoomIndicatorVisible = true
            } else if isZoomIndicatorVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    if currentZoomLevel == 1.0 {
                        withAnimation(.easeInOut(duration: 0.30)) {
                            isZoomIndicatorVisible = false
                        }
                    }
                }
            }
        }
        .onChange(of: browserState.focusAddressBarTabId) { _, targetId in
            if targetId == activeTabId {
                browserState.focusAddressBarTabId = nil
                browserState.openCommandPaletteForCurrentTab()
            }
        }
    }

    // MARK: - Toolbar Item View Builder

    @ViewBuilder
    private func toolbarItemView(for item: ToolbarItemType) -> some View {
        switch item {
        case .sidebarToggle:
            if isLeftmostContainer {
                sidebarToggleButton
            }
        case .back:
            backButton
        case .forward:
            forwardButton
        case .reload:
            reloadButton
        case .addressBar:
            addressBarItem
        case .splitView:
            splitViewButton
        case .downloads:
            if !browserState.activeProfileDownloads.isEmpty || browserState.activeFlyingDownload != nil || isDownloadsPopoverPresented {
                downloadsButton
            }
        case .shields:
            ShieldButton(browserState: browserState, tabId: activeTabId, theme: theme)
        case .media:
            if !browserState.mediaTabs.isEmpty {
                mediaButton
            }
        case .moreMenu:
            moreMenuButton
        }
    }

    // MARK: - Individual Toolbar Item Components

    private var sidebarToggleButton: some View {
        Button {
            browserState.toggleSidebar()
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 13, weight: .regular))
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .focusable(false)
    }

    private var backButton: some View {
        Button {
            backOffset = -2.5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                backOffset = 0
            }
            browserState.goBack(for: activeTabId)
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .medium))
                .offset(x: backOffset)
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: backOffset)
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .disabled(!canGoBack)
        .opacity(canGoBack ? 1.0 : 0.35)
        .animation(.easeInOut(duration: 0.2), value: canGoBack)
        .focusable(false)
        .contextMenu {
            let items = browserState.backHistoryList(for: activeTabId)
            if !items.isEmpty {
                ForEach(Array(items.prefix(15).enumerated()), id: \.offset) { _, item in
                    Button(historyItemTitle(item)) {
                        browserState.goToBackForwardItem(item, for: activeTabId)
                    }
                }
            }
        }
    }

    private var forwardButton: some View {
        Button {
            forwardOffset = 2.5
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                forwardOffset = 0
            }
            browserState.goForward(for: activeTabId)
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .offset(x: forwardOffset)
                .animation(.spring(response: 0.28, dampingFraction: 0.62), value: forwardOffset)
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .disabled(!canGoForward)
        .opacity(canGoForward ? 1.0 : 0.35)
        .animation(.easeInOut(duration: 0.2), value: canGoForward)
        .focusable(false)
        .contextMenu {
            let items = browserState.forwardHistoryList(for: activeTabId)
            if !items.isEmpty {
                ForEach(Array(items.prefix(15).enumerated()), id: \.offset) { _, item in
                    Button(historyItemTitle(item)) {
                        browserState.goToBackForwardItem(item, for: activeTabId)
                    }
                }
            }
        }
    }

    private var reloadButton: some View {
        Button {
            if isLoading {
                browserState.stopLoading(for: activeTabId)
            } else {
                browserState.reload(for: activeTabId)
            }
        } label: {
            ZStack {
                if isLoading {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 14, height: 14, alignment: .center)
                        .transition(.reloadTransition)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .regular))
                        .frame(width: 14, height: 14, alignment: .center)
                        .transition(.reloadTransition)
                }
            }
            .animation(.spring(response: 0.30, dampingFraction: 0.76), value: isLoading)
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .disabled(currentURL?.isLotusPage == true)
        .opacity(currentURL?.isLotusPage == true ? 0.35 : 1.0)
        .focusable(false)
        .contextMenu {
            Button {
                browserState.reload(for: activeTabId)
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
            }

            Button {
                browserState.reloadFromOrigin(for: activeTabId)
            } label: {
                Label("Force Reload (Bypass Cache)", systemImage: "arrow.clockwise.circle")
            }
        }
    }

    private var addressBarLeadingPadding: CGFloat {
        var padding: CGFloat = 8
        if shouldShowSecurityLock {
            padding += 20
        }
        return padding
    }

    private var addressBarTrailingPadding: CGFloat {
        var padding: CGFloat = 8
        if isZoomIndicatorVisible || currentZoomLevel != 1.0 {
            padding += 50
        }
        let shouldShowSplit = isInputHovered
        if shouldShowSplit {
            padding += 22
        }
        let activeTabProfileId = browserState.tab(for: activeTabId)?.profileId ?? browserState.currentProfileId
        let isCurrentBookmarked = browserState.isBookmarked(url: currentURL, profileId: activeTabProfileId)
        let shouldShowBookmark = (isCurrentBookmarked || isInputHovered) && currentURL != nil && currentURL?.isLotusPage == false
        if shouldShowBookmark {
            padding += 22
        }
        return padding
    }

    private var addressBarItem: some View {
        HStack(spacing: 0) {
            if browserState.isPrivate {
                PrivateBadgeView()
                    .padding(.trailing, 6)
            }

            ZStack(alignment: .leading) {
                // Leading elements: Lock / Security icon and Copy Feedback Chip (always left-aligned)
                HStack(spacing: 5) {
                    if shouldShowSecurityLock {
                        securityLockButton(for: currentURL)
                    }

                    if let feedback = urlCopyFeedback {
                        URLCopyFeedbackChip(feedback: feedback, theme: theme)
                            .id(feedback.id)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.88, anchor: .leading)
                                        .combined(with: .opacity)
                                        .animation(.spring(response: 0.28, dampingFraction: 0.78)),
                                    removal: .scale(scale: 0.88, anchor: .leading)
                                        .combined(with: .opacity)
                                        .animation(.easeInOut(duration: 0.20))
                                )
                            )
                    }
                }
                .padding(.leading, 7)
                .zIndex(2)

                if centerURLPreview && !isInputHovered {
                    // Centered prettified preview
                    HStack(spacing: 4) {
                        if let host = prettifiedHost {
                            Text(host)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundPrimary)

                            if let detail = prettifiedDetail {
                                Text("/")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(theme.foregroundSecondary.opacity(0.3))

                                Text(detail)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.foregroundSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        } else {
                            Text("Search the web or type a URL")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundSecondary)
                        }
                    }
                    .padding(.leading, addressBarLeadingPadding)
                    .padding(.trailing, addressBarTrailingPadding)
                    .padding(.vertical, 5)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    .transaction { $0.animation = nil }
                } else {
                    // Left-aligned layout (when hovering to see real URL or center preview is off)
                    HStack(spacing: 0) {
                        if isInputHovered && !urlInputText.isEmpty {
                            Text(urlInputText)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundPrimary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.leading, addressBarLeadingPadding)
                                .padding(.trailing, addressBarTrailingPadding)
                                .padding(.vertical, 5)
                        } else if let host = prettifiedHost {
                            HStack(spacing: 4) {
                                Text(host)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(theme.foregroundPrimary)

                                if let detail = prettifiedDetail {
                                    Text("/")
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundColor(theme.foregroundSecondary.opacity(0.3))

                                    Text(detail)
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundColor(theme.foregroundSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .padding(.leading, addressBarLeadingPadding)
                            .padding(.trailing, addressBarTrailingPadding)
                            .padding(.vertical, 5)
                        } else {
                            Text("Search the web or type a URL")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(theme.foregroundSecondary)
                                .padding(.leading, addressBarLeadingPadding)
                                .padding(.trailing, addressBarTrailingPadding)
                                .padding(.vertical, 5)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .transaction { $0.animation = nil }
                }

                // Trailing embedded elements (Zoom pill + Bookmark button + Split View button)
                HStack(spacing: 4) {
                    Spacer(minLength: 0)

                    if isZoomIndicatorVisible || currentZoomLevel != 1.0 {
                        ZoomIndicatorPill(
                            zoomLevel: currentZoomLevel,
                            isZoomingIn: browserState.lastZoomChangeDirection[activeTabId] ?? true,
                            theme: theme,
                            onReset: {
                                isZoomIndicatorVisible = true
                                browserState.resetZoom(for: activeTabId)
                            }
                        )
                        .transition(
                            .opacity.animation(.easeInOut(duration: 0.20))
                                .combined(with: .scale(scale: 0.90).animation(.easeInOut(duration: 0.20)))
                        )
                    }

                    let activeTabProfileId = browserState.tab(for: activeTabId)?.profileId ?? browserState.currentProfileId
                    let isCurrentBookmarked = browserState.isBookmarked(url: currentURL, profileId: activeTabProfileId)
                    let shouldShowBookmark = (isCurrentBookmarked || isInputHovered) && currentURL != nil && currentURL?.isLotusPage == false

                    let isSplitActive = browserState.isSplit(id: activeTabId)
                    let shouldShowSplit = isInputHovered
                    let group = browserState.splitGroup(containing: activeTabId)
                    let activeProfileId = browserState.tab(for: activeTabId)?.profileId ?? browserState.currentProfileId
                    let otherTabs = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == activeProfileId && !(group?.contains($0.id) ?? ($0.id == activeTabId)) && !$0.isPinned }

                    let isLeftPane = group?.first == activeTabId
                    let splitIconName: String = isSplitActive
                        ? (isLeftPane ? "rectangle.lefthalf.filled" : "rectangle.righthalf.filled")
                        : "rectangle.split.2x1"

                    if shouldShowSplit {
                        let splitColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : (isSplitActive ? Color.primary : theme.foregroundSecondary)
                        Menu {
                            if isSplitActive {
                                Button {
                                    browserState.closeSplit(id: activeTabId)
                                } label: {
                                    Label("Close Split View", systemImage: "rectangle.portrait.and.arrow.right")
                                }

                                if let group = group {
                                    Button {
                                        browserState.swapSplitTabs(for: group)
                                    } label: {
                                        Label("Swap Left & Right Sides", systemImage: "arrow.left.and.right.square")
                                    }
                                }

                                if !otherTabs.isEmpty {
                                    Divider()
                                    Menu("Replace Split Partner") {
                                        ForEach(otherTabs) { otherTab in
                                            Button(otherTab.title.isEmpty ? (otherTab.url?.host ?? "New Tab") : otherTab.title) {
                                                browserState.openInSplit(id: otherTab.id, side: .right)
                                            }
                                        }
                                    }
                                }
                            } else {
                                Button {
                                    browserState.openNewSplitTab(for: activeTabId)
                                } label: {
                                    Label("Split Right with New Tab", systemImage: "rectangle.righthalf.filled")
                                }

                                if !otherTabs.isEmpty {
                                    Menu("Split with Open Tab") {
                                        ForEach(otherTabs) { otherTab in
                                            Button(otherTab.title.isEmpty ? (otherTab.url?.host ?? "Untitled") : otherTab.title) {
                                                browserState.openInSplit(id: otherTab.id, side: .right)
                                            }
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: splitIconName)
                                .font(.system(size: 12, weight: isSplitActive ? .semibold : .regular))
                                .foregroundColor(splitColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        } primaryAction: {
                            if isSplitActive {
                                browserState.closeSplit(id: activeTabId)
                            } else {
                                browserState.openNewSplitTab(for: activeTabId)
                            }
                        }
                        .menuStyle(.button)
                        .buttonStyle(.plain)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .focusable(false)
                        .help(isSplitActive ? "Split View Active (Click to close, hold for options)" : "Split View (Click to split right, hold for options)")
                    }
                    
                    if shouldShowBookmark {
                        let bookmarkColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : (isCurrentBookmarked ? Color.primary : theme.foregroundSecondary)
                        Button {
                            browserState.toggleBookmark(for: activeTabId)
                        } label: {
                            Image(systemName: isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 12, weight: isCurrentBookmarked ? .semibold : .regular))
                                .foregroundColor(bookmarkColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .focusable(false)
                        .help(isCurrentBookmarked ? "Remove Bookmark (⌘D)" : "Bookmark Page (⌘D)")
                    }
                }
                .padding(.trailing, 4)
            }
            .transaction { $0.animation = nil }
            .frame(minWidth: 0, maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                browserState.openCommandPaletteForCurrentTab()
            }
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .background(
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.inputBackground(isFocused: false, isHovered: isInputHovered))

                    HairlineProgressIndicator(browserState: browserState, tabId: activeTabId)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            )
            .transaction { $0.animation = nil }
            .onHover { hovering in
                isInputHovered = hovering
            }
            .contextMenu {
                Button {
                    browserState.copyCleanPageURL(for: activeTabId)
                } label: {
                    Label("Copy Clean Address", systemImage: "sparkles")
                }
                .disabled(currentURL == nil || currentURL?.isLotusPage == true)

                Button {
                    browserState.copyPageURL(for: activeTabId, forceClean: false)
                } label: {
                    Label("Copy Full Address", systemImage: "link")
                }
                .disabled(currentURL == nil || currentURL?.isLotusPage == true)

                Divider()

                Button {
                    if let string = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
                        browserState.navigateTab(id: activeTabId, to: string)
                    }
                } label: {
                    Label("Paste and Go", systemImage: "arrow.right.circle")
                }
            }

        }
    }

    private var downloadsButton: some View {
        Button {
            isDownloadsPopoverPresented.toggle()
        } label: {
            ZStack {
                let activeColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : Color.primary
                if browserState.hasActiveDownloads {
                    ZStack {
                        Circle()
                            .stroke(activeColor.opacity(0.25), lineWidth: 2.0)
                            .frame(width: 15, height: 15)

                        Circle()
                            .trim(from: 0.0, to: clampedDownloadProgress)
                            .stroke(
                                activeColor,
                                style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 15, height: 15)
                            .animation(.linear(duration: 0.12), value: browserState.overallDownloadProgress)

                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(activeColor)
                    }
                    .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13, weight: .regular))
                }
            }
            .scaleEffect(isCatchingDownload ? 1.18 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.44), value: isCatchingDownload)
            .overlay(
                Group {
                    if showDownloadSuccessRing {
                        let activeColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : Color.primary
                        Circle()
                            .stroke(activeColor.opacity(0.90), lineWidth: 1.5)
                            .scaleEffect(downloadRingScale)
                            .opacity(downloadRingOpacity)
                    }
                }
            )
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let frame = geo.frame(in: .global)
                        browserState.downloadsButtonCenter = CGPoint(x: frame.midX, y: frame.midY)
                        browserState.isDownloadsButtonVisibleInToolbar = true
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in
                        browserState.downloadsButtonCenter = CGPoint(x: newFrame.midX, y: newFrame.midY)
                        browserState.isDownloadsButtonVisibleInToolbar = true
                    }
                    .onDisappear {
                        browserState.isDownloadsButtonVisibleInToolbar = false
                        browserState.downloadsButtonCenter = nil
                    }
            }
        )
        .focusable(false)
        .help("Downloads")
        .transition(.asymmetric(
            insertion: .scale(scale: 0.75).combined(with: .opacity),
            removal: .scale(scale: 0.75).combined(with: .opacity)
        ))
        .onChange(of: browserState.downloadCatchPulseTrigger) { _, _ in
            // 1. Double heartbeat spring bounce: 1.0 -> 1.18 -> 1.0
            showDownloadSuccessRing = true
            downloadRingScale = 0.80
            downloadRingOpacity = 0.90

            withAnimation(.spring(response: 0.16, dampingFraction: 0.40)) {
                isCatchingDownload = true
            }
            withAnimation(.easeOut(duration: 0.55)) {
                downloadRingScale = 1.85
                downloadRingOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.58)) {
                    isCatchingDownload = false
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
                showDownloadSuccessRing = false
            }
        }
        .popover(isPresented: $isDownloadsPopoverPresented, arrowEdge: .bottom) {
            RecentDownloadsPopover(browserState: browserState) {
                isDownloadsPopoverPresented = false
            }
        }
    }

    private var mediaButton: some View {
        let mediaColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : Color.primary
        return Button {
            isMediaPopoverPresented.toggle()
        } label: {
            Image(systemName: browserState.hasActiveAudioPlaying ? "waveform" : "play.tv")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(browserState.hasActiveAudioPlaying ? mediaColor : theme.foregroundSecondary)
        }
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .focusable(false)
        .help("Media Playback Controls")
        .popover(isPresented: $isMediaPopoverPresented, arrowEdge: .bottom) {
            GlobalMediaPopover(browserState: browserState)
        }
    }

    private var moreMenuButton: some View {
        Menu {
            Button {
                browserState.toggleSidebar()
            } label: {
                Label(
                    browserState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar",
                    systemImage: "sidebar.left"
                )
            }
            
            Divider()
            
            Button {
                browserState.addTabBelow(title: "Downloads", url: .lotusDownloads)
            } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }

            Button {
                browserState.addTabBelow(title: "History", url: .lotusHistory)
            } label: {
                Label("History", systemImage: "clock")
            }

            Button {
                browserState.addTabBelow(title: "Bookmarks", url: .lotusBookmarks)
            } label: {
                Label("Bookmarks", systemImage: "bookmark")
            }

            Button {
                browserState.addTabBelow(title: "Settings", url: .lotusSettings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Divider()

            Button {
                browserState.printPage(for: activeTabId)
            } label: {
                Label("Print", systemImage: "printer")
            }
            .disabled(currentURL?.isLotusPage != false)

            Button {
                browserState.togglePictureInPicture(for: activeTabId)
            } label: {
                Label("Picture in Picture", systemImage: "pip")
            }
            .disabled(currentURL?.isLotusPage != false)
            
            Button {
                browserState.openFind(for: activeTabId)
            } label: {
                Label("Find in Page", systemImage: "magnifyingglass")
            }
            .disabled(currentURL?.isLotusPage != false)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .regular))
        }
        .menuStyle(.button)
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .menuIndicator(.hidden)
        .fixedSize()
        .focusable(false)
    }

    private var splitViewButton: some View {
        let isSplitActive = browserState.isSplit(id: activeTabId)
        let group = browserState.splitGroup(containing: activeTabId)
        let activeProfileId = browserState.tab(for: activeTabId)?.profileId ?? browserState.currentProfileId
        let otherTabs = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == activeProfileId && !(group?.contains($0.id) ?? ($0.id == activeTabId)) && !$0.isPinned }
        let isLeftPane = group?.first == activeTabId
        let splitIconName: String = isSplitActive
            ? (isLeftPane ? "rectangle.lefthalf.filled" : "rectangle.righthalf.filled")
            : "rectangle.split.2x1"
        let splitColor = theme.themeColor != nil ? (theme.isThemeLight ? Color.black : Color.white) : Color.primary

        return Menu {
            if isSplitActive {
                Button {
                    browserState.closeSplit(id: activeTabId)
                } label: {
                    Label("Close Split View", systemImage: "rectangle.portrait.and.arrow.right")
                }

                if let group = group {
                    Button {
                        browserState.swapSplitTabs(for: group)
                    } label: {
                        Label("Swap Left & Right Sides", systemImage: "arrow.left.and.right.square")
                    }
                }

                if !otherTabs.isEmpty {
                    Divider()
                    Menu("Replace Split Partner") {
                        ForEach(otherTabs) { otherTab in
                            Button(otherTab.title.isEmpty ? (otherTab.url?.host ?? "New Tab") : otherTab.title) {
                                browserState.openInSplit(id: otherTab.id, side: .right)
                            }
                        }
                    }
                }
            } else {
                Button {
                    browserState.openNewSplitTab(for: activeTabId)
                } label: {
                    Label("Split Right with New Tab", systemImage: "rectangle.righthalf.filled")
                }

                if !otherTabs.isEmpty {
                    Menu("Split with Open Tab") {
                        ForEach(otherTabs) { otherTab in
                            Button(otherTab.title.isEmpty ? (otherTab.url?.host ?? "Untitled") : otherTab.title) {
                                browserState.openInSplit(id: otherTab.id, side: .right)
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: splitIconName)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(splitColor)
        } primaryAction: {
            if isSplitActive {
                browserState.closeSplit(id: activeTabId)
            } else {
                browserState.openNewSplitTab(for: activeTabId)
            }
        }
        .menuStyle(.button)
        .buttonStyle(BrowserToolbarButtonStyle(isLight: theme.isThemeLight, hasCustomTheme: theme.themeColor != nil))
        .menuIndicator(.hidden)
        .fixedSize()
        .focusable(false)
        .help(isSplitActive ? "Split View Active (Click to close, hold for options)" : "Split View (Click to split right, hold for options)")
    }

    private func historyItemTitle(_ item: WKBackForwardListItem) -> String {
        if let title = item.title, !title.isEmpty {
            return title
        }
        if let host = item.url.host, !host.isEmpty {
            return host
        }
        return item.url.absoluteString
    }

    private var isEditingOrHovering: Bool {
        isInputHovered
    }

    private var urlCopyFeedback: URLCopyFeedback? {
        guard let feedback = browserState.urlCopyFeedback, feedback.tabId == activeTabId else { return nil }
        return feedback
    }

    @ViewBuilder
    private func securityLockButton(for url: URL?) -> some View {
        if browserState.pageLoadErrors[activeTabId] != nil {
            Button {
                isSecurityPopoverPresented.toggle()
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .popover(isPresented: $isSecurityPopoverPresented, arrowEdge: .bottom) {
                SecurityDetailsPopover(browserState: browserState, tabId: activeTabId)
            }
        } else if let url = url {
            Button {
                isSecurityPopoverPresented.toggle()
            } label: {
                Image(systemName: url.scheme?.lowercased() == "https" ? "lock.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(url.scheme?.lowercased() == "https" ? theme.foregroundSecondary.opacity(0.65) : .orange)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .popover(isPresented: $isSecurityPopoverPresented, arrowEdge: .bottom) {
                SecurityDetailsPopover(browserState: browserState, tabId: activeTabId)
            }
        }
    }

    private var shouldShowSecurityLock: Bool {
        if browserState.pageLoadErrors[activeTabId] != nil {
            return true
        }
        guard let url = currentURL else { return false }
        return !url.isLotusPage
    }

    private var prettifiedHost: String? {
        if let error = browserState.pageLoadErrors[activeTabId] {
            return error.title
        }
        guard let url = currentURL else { return nil }
        if let lotusTitle = url.lotusPageTitle {
            return lotusTitle
        }
        guard let host = url.host, !host.isEmpty else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var prettifiedDetail: String? {
        if let error = browserState.pageLoadErrors[activeTabId] {
            if let host = error.url?.host, !host.isEmpty {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            if let abs = error.url?.absoluteString, !abs.isEmpty, abs != error.title {
                return abs
            }
            return nil
        }
        guard let url = currentURL, !url.isLotusPage else { return nil }
        if let title = currentTab?.title, !title.isEmpty, title != prettifiedHost, title != url.absoluteString {
            return title
        }
        if !url.path.isEmpty && url.path != "/" {
            return url.path
        }
        return nil
    }

    private func handleTabSwitch() {
        syncInputText()
    }

    private func syncInputText() {
        if let error = browserState.pageLoadErrors[activeTabId], let errorURL = error.url {
            urlInputText = errorURL.absoluteString
        } else if let url = currentURL, url.isLotusPage {
            // Show the URL for internal pages (e.g. lotus://history).
            urlInputText = url.absoluteString
        } else if let abs = currentURL?.absoluteString, !abs.isEmpty {
            urlInputText = abs
        } else {
            urlInputText = currentTab?.title ?? ""
        }
    }

    private func submit(with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        browserState.navigateTab(id: activeTabId, to: trimmed)
    }
}

private struct URLCopyFeedbackChip: View {
    let feedback: URLCopyFeedback
    let theme: BrowserChromeTheme

    @Environment(\.colorScheme) private var colorScheme

    private var isSuccess: Bool {
        feedback.outcome == .copied || feedback.outcome == .cleanCopied
    }

    private var labelText: String {
        switch feedback.outcome {
        case .cleanCopied:
            return "Clean URL"
        case .copied:
            return "Copied"
        case .failed:
            return "Failed"
        }
    }

    private var iconName: String {
        switch feedback.outcome {
        case .cleanCopied, .copied:
            return "checkmark"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 9, weight: .bold))

            Text(labelText)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(
            isSuccess
                ? theme.foregroundPrimary.opacity(0.85)
                : .red.opacity(0.9)
        )
        .padding(.horizontal, 5.5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.12)
                        : Color.black.opacity(0.06)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - Reload / Stop Icon Transition

private struct SpinAndScaleTransitionModifier: ViewModifier {
    let rotation: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private extension AnyTransition {
    static var reloadTransition: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SpinAndScaleTransitionModifier(rotation: -90, scale: 0.6, opacity: 0),
                identity: SpinAndScaleTransitionModifier(rotation: 0, scale: 1.0, opacity: 1)
            ),
            removal: .modifier(
                active: SpinAndScaleTransitionModifier(rotation: 90, scale: 0.6, opacity: 0),
                identity: SpinAndScaleTransitionModifier(rotation: 0, scale: 1.0, opacity: 1)
            )
        )
    }
}

// MARK: - Zoom Indicator Pill

private struct ZoomIndicatorPill: View {
    let zoomLevel: CGFloat
    let isZoomingIn: Bool
    let theme: BrowserChromeTheme
    let onReset: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var percentValue: Int {
        Int(round(zoomLevel * 100))
    }

    private var percentText: String {
        "\(percentValue)%"
    }

    var body: some View {
        Button(action: onReset) {
            HStack(spacing: 2) {
                Text("\(percentValue)")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: !isZoomingIn))
                    // Keep the rolling digits in a stable vertical lane. Without
                    // this, the transition's intermediate glyphs can move the
                    // pill's baseline up and down as their bounds change.
                    .frame(height: 13, alignment: .center)
                    .clipped()

                Text("%")
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.74), value: percentValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(theme.foregroundPrimary.opacity(isHovered ? 1.0 : 0.72))
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(isHovered
                          ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                          : (colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help("Zoom level \(percentText). Click to reset to 100%.")
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

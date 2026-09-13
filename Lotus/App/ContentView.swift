//
//  ContentView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit
import WebKit

struct ContentView: View {
    @StateObject private var browserState: BrowserState
    let isPrivate: Bool

    init(isPrivate: Bool = false) {
        self.isPrivate = isPrivate
        _browserState = StateObject(wrappedValue: BrowserState(isPrivate: isPrivate))
    }

    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @State private var isHoveringFloatingSidebar: Bool = false
    @State private var isFloatingSidebarTemporarilyShown: Bool = false
    @State private var temporaryFloatingDismissTask: DispatchWorkItem? = nil

    private var currentAccentColor: Color {
        if !browserState.isPrivate {
            if browserState.currentProfile.color == .grey {
                return Color(nsColor: .controlAccentColor)
            }
            return browserState.currentProfile.color.color
        }
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    private var shouldShowFloatingSidebar: Bool {
        !browserState.isSidebarVisible
            && (isHoveringFloatingSidebar || isFloatingSidebarTemporarilyShown || browserState.activeTabDrag != nil || browserState.isResizingSidebar || browserState.profileSwipeOffset != 0)
    }

    private var isStaticSidebarPresented: Bool {
        browserState.isSidebarVisible
    }

    var body: some View {
        GeometryReader { windowGeo in
            let windowWidth = windowGeo.size.width
            let windowHeight = windowGeo.size.height

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // MARK - Static Sidebar
                    Tabstrip(browserState: browserState)
                        .frame(
                            width: isStaticSidebarPresented ? browserState.sidebarWidth : 0,
                            alignment: .trailing
                        )
                        .clipped()
                        .opacity(isStaticSidebarPresented ? 1 : 0)
                        .allowsHitTesting(isStaticSidebarPresented)
                        .zIndex(1)

                    // MARK - Browser Containers
                    browserContentArea
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding([.top, .trailing, .bottom], showsBrowserFrame ? 6 : 0)
                    .padding(.leading, isStaticSidebarPresented ? 0 : (showsBrowserFrame ? 6 : 0))
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isStaticSidebarPresented)

                // Hover trigger zone on the left edge when sidebar is collapsed
                if !browserState.isSidebarVisible && !shouldShowFloatingSidebar {
                    Color.white.opacity(0)
                        .frame(width: 18)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    isHoveringFloatingSidebar = true
                                }
                            }
                        }
                        .zIndex(5)
                }

                // Floating sidebar overlay when collapsed and hovered or temporarily shown
                if shouldShowFloatingSidebar {
                    floatingSidebar
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .zIndex(10)
                }

                // MARK - Split View Drop Zone Preview Overlay
                if let drag = browserState.activeTabDrag,
                   drag.folder == nil,
                   drag.draggedUnitCount == 1,
                   drag.effectiveDraggedUnits.first?.isSplit == false,
                   browserState.canOpenInSplit(id: drag.tab.id),
                   drag.location.x >= browserState.sidebarWidth {
                    let (leftCardFrame, rightCardFrame) = browserState.splitTargetFrames(windowWidth: windowWidth, windowHeight: windowHeight)
                    let (dragColor, _) = browserState.effectiveTabColor(for: drag.tab, colorScheme: colorScheme)

                    ZStack {
                        SplitDropZoneCard(
                            side: .left,
                            isHovered: drag.splitDropTarget == .left,
                            mouseLocation: drag.location,
                            cardFrame: leftCardFrame,
                            accentColor: dragColor
                        )

                        SplitDropZoneCard(
                            side: .right,
                            isHovered: drag.splitDropTarget == .right,
                            mouseLocation: drag.location,
                            cardFrame: rightCardFrame,
                            accentColor: dragColor
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .allowsHitTesting(false)
                    .zIndex(500)
                }

                // MARK - Global Floating Drag Tab
                if let drag = browserState.activeTabDrag {
                    let sidebarW: CGFloat = browserState.sidebarWidth
                    let inSidebar = drag.location.x < sidebarW
                    let floatingX: CGFloat = inSidebar
                        ? (drag.isHoveringPinZone ? drag.location.x : (sidebarW / 2))
                        : drag.location.x

                    let dragProfile = browserState.profile(for: drag.tab.profileId ?? browserState.currentProfileId) ?? browserState.currentProfile
                    let (dragColor, dragIsLight) = browserState.effectiveTabColor(for: drag.tab, colorScheme: colorScheme)

                    FloatingDragTab(
                        tab: drag.tab,
                        splitPair: browserState.splitPair(for: drag.tab.id),
                        isPinnedPreview: drag.isHoveringPinZone && inSidebar,
                        pinnedCardWidth: dynamicPinnedCardWidth(for: sidebarW),
                        // Live preview: the ghost shrinks to folder width when
                        // the drop position would land inside a folder.
                        sidebarWidth: sidebarW - (drag.wouldJoinFolder ? 14 : 0),
                        isThemeLight: dragIsLight,
                        activeTabBackgroundColor: dragColor,
                        profileColor: dragProfile.color.color,
                        folder: drag.folder,
                        folderTabCount: drag.folder.map { browserState.folderTabs($0.id).count } ?? 0,
                        previewCount: drag.folder == nil && drag.draggedUnitCount > 1
                            ? drag.draggedTabIds.count
                            : 1
                    )
                    .animation(.spring(response: 0.24, dampingFraction: 0.82), value: drag.wouldJoinFolder)
                    .position(x: floatingX, y: drag.location.y)
                    .allowsHitTesting(false)
                    .zIndex(9999)
                }
            }
            .coordinateSpace(name: "lotusWindow")
        }
        .frame(minWidth: 500, minHeight: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(frostedGlassBackground)
        .background(TrafficLightPositioner(
            leading: (shouldShowFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            top: (shouldShowFloatingSidebar && !browserState.isSidebarVisible) ? 22 : 20,
            isVisible: isStaticSidebarPresented || shouldShowFloatingSidebar
        ))
        .background {
            GlobalShortcutHandlers(browserState: browserState)
        }
        .overlay {
            if browserState.isCommandPaletteOpen {
                CommandPalette(browserState: browserState)
            }
        }
        .overlay { modalOverlays }
        .overlay { flyingDownloadOverlay }
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.isQuitConfirmationPresented)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.folderToCloseConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.isClearAllDataConfirmationPresented)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.profileToDeleteConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.deleteBangConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.historyConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.downloadConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.bookmarkConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.websiteDataConfirmation != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.activeJavaScriptDialog != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.profileToEdit != nil)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: browserState.isCreatingProfile)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: isStaticSidebarPresented)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: shouldShowFloatingSidebar)
        .onChange(of: browserState.isSidebarVisible) { _, visible in
            temporaryFloatingDismissTask?.cancel()
            temporaryFloatingDismissTask = nil

            if visible {
                isHoveringFloatingSidebar = false
                isFloatingSidebarTemporarilyShown = false
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isFloatingSidebarTemporarilyShown = true
                }

                let task = DispatchWorkItem {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isFloatingSidebarTemporarilyShown = false
                    }
                }
                temporaryFloatingDismissTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
            }
        }
        .onChange(of: browserState.currentProfileId) { _, _ in
            if !browserState.isSidebarVisible {
                temporaryFloatingDismissTask?.cancel()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isFloatingSidebarTemporarilyShown = true
                }
                let task = DispatchWorkItem {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isFloatingSidebarTemporarilyShown = false
                    }
                }
                temporaryFloatingDismissTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: task)
            }
        }
        .onAppear {
            AppDelegate.sharedBrowserState = browserState
            browserState.onOpenNewWindow = { url, isPrivate in
                AppDelegate.enqueuePendingURL(url, isPrivate: isPrivate)
                openWindow(id: isPrivate ? "private" : "main")
            }
            if let pendingURL = AppDelegate.dequeuePendingURL(isPrivate: isPrivate) {
                browserState.openTab(at: pendingURL, title: pendingURL.host ?? "New Tab")
            }
        }
        .onChange(of: controlActiveState) { _, newState in
            if newState == .key {
                AppDelegate.sharedBrowserState = browserState
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lotusOpenNewWindow)) { notif in
            handleOpenNewWindow(url: notif.object as? URL)
        }
        .onReceive(NotificationCenter.default.publisher(for: .lotusOpenNewPrivateWindow)) { notif in
            handleOpenNewPrivateWindow(url: notif.object as? URL)
        }
        .tint(currentAccentColor)
        .accentColor(currentAccentColor)
    }

    private func handleOpenNewWindow(url: URL?) {
        if let url = url {
            AppDelegate.enqueuePendingURL(url, isPrivate: false)
        }
        openWindow(id: "main")
    }

    private func handleOpenNewPrivateWindow(url: URL?) {
        if let url = url {
            AppDelegate.enqueuePendingURL(url, isPrivate: true)
        }
        openWindow(id: "private")
    }

    @ViewBuilder
    private var modalOverlays: some View {
        if browserState.isQuitConfirmationPresented {
            QuitConfirmationView(browserState: browserState)
        }
        if browserState.folderToCloseConfirmation != nil {
            FolderCloseConfirmationView(browserState: browserState)
        }
        if browserState.isClearAllDataConfirmationPresented {
            ClearAllDataConfirmationView(browserState: browserState)
        }
        if let profile = browserState.profileToDeleteConfirmation {
            DeleteProfileConfirmationView(browserState: browserState, profile: profile)
        }
        if let bang = browserState.deleteBangConfirmation {
            DeleteBangConfirmationView(
                bang: bang,
                onConfirm: {
                    CustomBangsStore.shared.removeBang(id: bang.id)
                    browserState.deleteBangConfirmation = nil
                },
                onCancel: {
                    browserState.deleteBangConfirmation = nil
                }
            )
        }
        if let confirmation = browserState.historyConfirmation {
            HistoryConfirmationView(
                confirmation: confirmation,
                onCancel: {
                    browserState.historyConfirmation = nil
                },
                onConfirm: {
                    switch confirmation {
                    case .clearAll:
                        browserState.clearHistory(for: browserState.currentProfileId)
                    case .deleteSelected(let ids):
                        browserState.removeHistoryEntries(ids: ids)
                    }
                    browserState.historyConfirmation = nil
                }
            )
        }
        if let confirmation = browserState.downloadConfirmation {
            DownloadConfirmationView(
                confirmation: confirmation,
                onCancel: {
                    browserState.downloadConfirmation = nil
                },
                onConfirm: {
                    switch confirmation {
                    case .clearAll:
                        browserState.clearAllDownloads(for: browserState.currentProfileId)
                    case .deleteSelected(let ids):
                        browserState.removeDownloads(ids: ids)
                    }
                    browserState.downloadConfirmation = nil
                }
            )
        }
        if let confirmation = browserState.bookmarkConfirmation {
            BookmarkConfirmationView(
                confirmation: confirmation,
                onCancel: {
                    browserState.bookmarkConfirmation = nil
                },
                onConfirm: {
                    switch confirmation {
                    case .deleteSingle(let bookmark):
                        browserState.removeBookmark(id: bookmark.id)
                    case .deleteSelected(_, let ids):
                        for id in ids {
                            browserState.removeBookmark(id: id)
                        }
                    }
                    browserState.bookmarkConfirmation = nil
                }
            )
        }
        if let confirmation = browserState.websiteDataConfirmation {
            WebsiteDataConfirmationView(
                confirmation: confirmation,
                onCancel: {
                    browserState.websiteDataConfirmation = nil
                },
                onConfirm: {
                    switch confirmation {
                    case .clearAll:
                        browserState.fetchWebsiteDataRecords { records in
                            browserState.removeWebsiteData(records: records)
                        }
                    case .deleteSelected(let domains):
                        browserState.fetchWebsiteDataRecords { records in
                            let targetRecords = records.filter { domains.contains($0.displayName) }
                            browserState.removeWebsiteData(records: targetRecords)
                        }
                    }
                    browserState.websiteDataConfirmation = nil
                }
            )
        }
        if let dialog = browserState.activeJavaScriptDialog {
            JavaScriptDialogView(browserState: browserState, request: dialog)
        }
        if let profile = browserState.profileToEdit {
            EditProfileDialogView(
                profile: profile,
                canDelete: browserState.canDeleteProfile(profile),
                onSave: { updated in
                    browserState.updateProfile(updated)
                    browserState.profileToEdit = nil
                },
                onDelete: { toDelete in
                    browserState.profileToEdit = nil
                    browserState.requestDeleteProfile(toDelete)
                },
                onCancel: {
                    browserState.profileToEdit = nil
                }
            )
        }
        if browserState.isCreatingProfile {
            CreateProfileDialogView(
                onSave: { name, icon, color in
                    let created = browserState.createProfile(name: name, icon: icon, color: color)
                    browserState.switchProfile(to: created.id, direction: .forward)
                    browserState.isCreatingProfile = false
                },
                onCancel: {
                    browserState.isCreatingProfile = false
                }
            )
        }
    }

    @ViewBuilder
    private var flyingDownloadOverlay: some View {
        if let flyingPayload = browserState.activeFlyingDownload,
           browserState.isDownloadsConfiguredInToolbar {
            GeometryReader { overlayGeo in
                let defaultTargetX = overlayGeo.size.width - 80
                let defaultTargetY: CGFloat = 20
                let target = browserState.downloadsButtonCenter ?? CGPoint(x: defaultTargetX, y: defaultTargetY)
                FlyingDownloadView(
                    payload: flyingPayload,
                    targetPoint: target,
                    browserState: browserState
                ) {
                    browserState.downloadCatchPulseTrigger += 1
                    HapticFeedback.perform(.alignment, performanceTime: .now)
                    browserState.activeFlyingDownload = nil
                }
            }
            .ignoresSafeArea()
            .zIndex(99999)
        }
    }

    private var floatingSidebar: some View {
        Tabstrip(browserState: browserState)
            .frame(width: browserState.sidebarWidth, alignment: .leading)
            .background(
                ZStack {
                    VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                    currentAccentColor
                        .opacity((browserState.currentProfile.color == .grey || accentColorKey == "white") ? 0 : (colorScheme == .dark ? 0.18 : 0.32))
                        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: browserState.currentProfileId)
                        .animation(.spring(response: 0.35, dampingFraction: 0.88), value: accentColorKey)
                    (colorScheme == .dark ? Color.black.opacity(0.35) : Color(nsColor: .windowBackgroundColor).opacity(0.75))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14), radius: 14, x: 2, y: 1)
            .padding(3)
            .contentShape(Rectangle())
            .onHover { hovering in
                if !browserState.isResizingSidebar && browserState.activeTabDrag == nil && browserState.profileSwipeOffset == 0 {
                    if hovering {
                        temporaryFloatingDismissTask?.cancel()
                        temporaryFloatingDismissTask = nil
                    }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        isHoveringFloatingSidebar = hovering
                        if hovering {
                            isFloatingSidebarTemporarilyShown = false
                        }
                    }
                }
            }
    }


    private var emptyBrowserContainer: some View {
        RoundedRectangle(cornerRadius: showsRoundedWebCorners ? 10 : 0, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: showsRoundedWebCorners ? 10 : 0, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var browserContentArea: some View {
        let currentTabIds = browserState.currentTabIds
        if currentTabIds.isEmpty {
            emptyBrowserContainer
        } else if currentTabIds.count == 2 {
            splitBrowserContainers(for: currentTabIds)
        } else if let tabId = currentTabIds.first {
            BrowserContainer(browserState: browserState, tabId: tabId)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(browserState.selectedTabId == tabId ? 1 : 0)
                .transition(.identity)
        }
    }

    private func splitBrowserContainers(for currentTabIds: [UUID]) -> some View {
        GeometryReader { splitGeo in
            let totalWidth = splitGeo.size.width
            let spacing: CGFloat = 6
            let availableWidth = max(0, totalWidth - spacing)
            let ratio = browserState.splitRatio(for: currentTabIds)
            let minWidth: CGFloat = min(220, max(140, availableWidth * 0.20))
            let leftWidth = max(minWidth, min(availableWidth - minWidth, availableWidth * ratio))
            let rightWidth = max(minWidth, availableWidth - leftWidth)

            let leftId = currentTabIds[0]
            let rightId = currentTabIds[1]

            HStack(spacing: 0) {
                BrowserContainer(browserState: browserState, tabId: leftId)
                    .frame(width: leftWidth)
                    .frame(maxHeight: .infinity)
                    .zIndex(browserState.selectedTabId == leftId ? 2 : 0)
                    .transition(.identity)

                SplitResizeHandle(
                    browserState: browserState,
                    group: currentTabIds,
                    availableWidth: availableWidth,
                    minWidth: minWidth,
                    spacing: spacing
                )
                .frame(width: spacing)
                .zIndex(50)

                BrowserContainer(browserState: browserState, tabId: rightId)
                    .frame(width: rightWidth)
                    .frame(maxHeight: .infinity)
                    .zIndex(browserState.selectedTabId == rightId ? 2 : 0)
                    .transition(.identity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func dynamicPinnedCardWidth(for sidebarWidth: CGFloat) -> CGFloat {
        let effectiveCount: Int
        if let drag = browserState.activeTabDrag, drag.folder == nil {
            let draggedPinnedCount = browserState.pinnedTabs.filter { drag.draggedTabIds.contains($0.id) }.count
            let remainingCount = browserState.pinnedTabs.count - draggedPinnedCount
            effectiveCount = drag.isHoveringPinZone && drag.canPinPayload
                ? remainingCount + drag.draggedTabIds.count
                : remainingCount
        } else {
            effectiveCount = browserState.pinnedTabs.count
        }
        let count = max(1, effectiveCount)
        let cols = count <= 4 ? count : 3
        return max(20, (sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols))
    }

    private var frostedGlassBackground: some View {
        ZStack {
            VisualEffectView(
                material: .underWindowBackground,
                blendingMode: .behindWindow,
                state: .active
            )
            currentAccentColor
                .opacity((browserState.currentProfile.color == .grey || accentColorKey == "white") ? 0 : (colorScheme == .dark ? 0.16 : 0.20))
                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: browserState.currentProfileId)
                .animation(.spring(response: 0.35, dampingFraction: 0.88), value: accentColorKey)
            (colorScheme == .dark ? Color.black.opacity(0.12) : Color.white.opacity(0.04))
        }
        .ignoresSafeArea()
    }
}

// MARK: - Split Drop Zone Card

private struct SplitDropZoneCard: View {
    let side: TabDragState.SplitDropTarget
    let isHovered: Bool
    let mouseLocation: CGPoint
    let cardFrame: CGRect
    var accentColor: Color = Color.accentColor
    @Environment(\.colorScheme) private var colorScheme

    private var magneticOffset: CGSize {
        let center = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        let dx = mouseLocation.x - center.x
        let dy = mouseLocation.y - center.y
        let distance = hypot(dx, dy)

        // Expanded magnetic radius
        let magneticRadius: CGFloat = 350.0
        guard distance < magneticRadius else { return .zero }

        let proximity = 1.0 - (distance / magneticRadius)
        let smoothFactor = proximity * (2.0 - proximity)

        // The card leans harder into the cursor once it's actually hovered.
        let pullStrength: CGFloat = isHovered ? 0.40 : 0.25
        let pullX = dx * pullStrength * smoothFactor
        let pullY = dy * pullStrength * smoothFactor
        let maxOffsetX: CGFloat = isHovered ? 50 : 25
        let maxOffsetY: CGFloat = isHovered ? 50 : 25
        return CGSize(
            width: max(-maxOffsetX, min(maxOffsetX, pullX)),
            height: max(-maxOffsetY, min(maxOffsetY, pullY))
        )
    }

    private var magneticScale: CGFloat {
        if isHovered {
            return 1.02
        }
        let center = CGPoint(x: cardFrame.midX, y: cardFrame.midY)
        let distance = hypot(mouseLocation.x - center.x, mouseLocation.y - center.y)
        let magneticRadius: CGFloat = 500.0
        if distance < magneticRadius {
            let proximity = 1.0 - (distance / magneticRadius)
            return 1.0 + (0.012 * proximity)
        }
        return 1.0
    }

    private var strokeColor: Color {
        if isHovered {
            return accentColor.opacity(colorScheme == .dark ? 0.95 : 0.85)
        }
        return colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var foregroundColor: Color {
        if isHovered {
            return accentColor
        }
        return colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.60)
    }

    var body: some View {
        TimelineView(.animation(paused: !isHovered)) { timeline in
            let phase: CGFloat = isHovered ? CGFloat(timeline.date.timeIntervalSinceReferenceDate * 32.0).truncatingRemainder(dividingBy: 28.0) : 0

            ZStack {
                // Glassy sidebar material background (consistent across hover)
                VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
                    .overlay(
                        (colorScheme == .dark ? Color.black.opacity(0.35) : Color(nsColor: .windowBackgroundColor).opacity(0.75))
                    )
                    .overlay(
                        isHovered ? accentColor.opacity(colorScheme == .dark ? 0.12 : 0.08) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                // Inset dashed border
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        strokeColor,
                        style: StrokeStyle(
                            lineWidth: isHovered ? 2.5 : 2.0,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [8, 6],
                            dashPhase: -phase
                        )
                    )
                    .padding(6)

                VStack(spacing: 12) {
                    Image(systemName: side == .left ? "rectangle.leadinghalf.filled" : "rectangle.righthalf.filled")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(foregroundColor)

                    Text(side == .left ? "Add left split" : "Add right split")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.14),
                radius: 14,
                x: 0,
                y: 2
            )
            .frame(width: cardFrame.width, height: cardFrame.height)
            .offset(magneticOffset)
            .scaleEffect(magneticScale)
            .position(x: cardFrame.midX, y: cardFrame.midY)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isHovered)
            .allowsHitTesting(false)
        }
    }
}

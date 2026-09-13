//
//  Tabstrip.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

struct Tabstrip: View {
    @ObservedObject var browserState: BrowserState
    @State var dragStartWidth: CGFloat? = nil
    @State var activeDrag: TabDragState? = nil
    @Namespace private var tabAnimationNamespace

    let minWidth: CGFloat = 150
    let maxWidth: CGFloat = 600
    let defaultWidth: CGFloat = 240
    let snapThreshold: CGFloat = 8
    let collapseThreshold: CGFloat = 130
    let headerHeight: CGFloat = 50
    let rowHeight: CGFloat = 37 // 34pt tab + 3pt spacing
    let pinnedRowHeight: CGFloat = 46 // 38pt card + 8pt spacing
    let newTabButtonHeight: CGFloat = 36

    @State var isSnappedToDefault: Bool = false
    @State var isDragCollapsed: Bool = false
    @State var wasInitiallyVisibleOnDragStart: Bool = false
    @State private var renamingFolderId: UUID? = nil
    @State private var renamingTabId: UUID? = nil
    @State var unpinnedScrollOffset: CGFloat = 0

    @AppStorage("lotus.browser.smoothTabSwitchAnimation") private var smoothTabSwitchAnimation: Bool = true
    @State private var enableMatchedGeometry: Bool = false
    @State private var previousSelectedTabId: UUID? = nil

    private var tabSelectionAnimation: Animation? {
        smoothTabSwitchAnimation
            ? Animation.spring(response: 0.20, dampingFraction: 0.86, blendDuration: 0.02)
            : nil
    }

    private func isUnpinnedTabInCurrentProfile(_ tabId: UUID?) -> Bool {
        guard let id = tabId, let tab = browserState.tab(for: id) else { return false }
        return !tab.isPinned && (tab.profileId ?? browserState.defaultProfileId) == browserState.currentProfileId
    }

    private var highlightedTabId: UUID {
        browserState.selectedTabId
    }

    private var highlightedCurrentTabIds: [UUID] {
        browserState.splitGroup(containing: browserState.selectedTabId) ?? [browserState.selectedTabId]
    }

    private var isPinnedTabSelected: Bool {
        browserState.activeTab?.isPinned == true
    }

    private var hasMultipleSelectedTabs: Bool {
        let selectedIds = browserState.selectedSidebarTabIds
        return browserState.visibleSidebarUnits.filter { unit in
            unit.tabIds.contains(where: selectedIds.contains)
        }.count > 1
    }

    @AppStorage("lotus.browser.sidebarTabTintingMode") private var sidebarTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"
    @Environment(\.colorScheme) private var colorScheme

    private func selectedTabId(for profileId: UUID) -> UUID? {
        if profileId == browserState.currentProfileId {
            return browserState.selectedTabId
        }
        if let saved = browserState.lastSelectedTabPerProfile[profileId] {
            return saved
        }
        return browserState.tabs.first(where: { ($0.profileId ?? browserState.defaultProfileId) == profileId })?.id
    }

    private func currentTabIds(for profileId: UUID) -> [UUID] {
        if profileId == browserState.currentProfileId {
            return browserState.currentTabIds
        }
        if let saved = browserState.lastCurrentTabsPerProfile[profileId], !saved.isEmpty {
            return saved
        }
        if let sel = selectedTabId(for: profileId) {
            return [sel]
        }
        return []
    }

    private func activeTabBackgroundColor(for profile: Profile) -> Color {
        let isCurrent = (profile.id == browserState.currentProfileId)
        let profTabId = selectedTabId(for: profile.id)
        let isInternal = profTabId.flatMap({ browserState.url(for: $0)?.isLotusPage }) ?? false
        if isInternal {
            return Color(nsColor: .windowBackgroundColor)
        }
        switch sidebarTabTintingMode {
        case "neutral":
            return Color(nsColor: .windowBackgroundColor)
        case "systemAccent":
            if profile.color == .grey {
                return Color(nsColor: .windowBackgroundColor)
            }
            return profile.color.color
        default: // "adaptive"
            if let tabId = profTabId {
                return browserState.effectiveTabTheme(for: tabId)?.color
                    ?? (isCurrent ? browserState.activeThemeColor : nil)
                    ?? Color(nsColor: .windowBackgroundColor)
            }
            return Color(nsColor: .windowBackgroundColor)
        }
    }

    private func isTabThemeLight(for tabId: UUID) -> Bool {
        let isInternal = browserState.url(for: tabId)?.isLotusPage == true
        if isInternal {
            return colorScheme == .light
        }
        switch sidebarTabTintingMode {
        case "neutral":
            return colorScheme == .light
        case "systemAccent":
            if browserState.currentProfile.color == .grey {
                return colorScheme == .light
            }
            let accent = LotusAccentColor(rawValue: browserState.currentProfile.color.accentColorEquivalent.rawValue) ?? .white
            return accent == .yellow
        default: // "adaptive"
            if let theme = browserState.effectiveTabTheme(for: tabId) {
                return theme.isLight
            }
            if browserState.themeColor(for: tabId) == nil && (tabId != browserState.selectedTabId || browserState.activeThemeColor == nil) {
                return colorScheme == .light
            }
            return browserState.isThemeLight(for: tabId)
        }
    }

    func pinnedTabs(for profileId: UUID) -> [TabItem] {
        browserState.tabs.filter { $0.isPinned && ($0.profileId ?? browserState.defaultProfileId) == profileId }
    }

    /// Pinned-grid footprint after removing the drag payload from its source
    /// and, when applicable, reserving all of its destination slots.
    func effectivePinnedCount(for profileId: UUID) -> Int {
        let baseCount = pinnedTabs(for: profileId).count
        guard profileId == browserState.currentProfileId, let drag = activeDrag, drag.folder == nil else {
            return baseCount
        }
        let draggedPinnedCount = pinnedTabs(for: profileId).filter { drag.draggedTabIds.contains($0.id) }.count
        let remainingCount = baseCount - draggedPinnedCount
        if drag.isHoveringPinZone && drag.canPinPayload {
            return remainingCount + drag.draggedTabIds.count
        }
        return remainingCount
    }

    var effectivePinnedCount: Int {
        effectivePinnedCount(for: browserState.currentProfileId)
    }

    /// Dynamic column count: up to 4 tabs sit in a single row; 5+ wraps to 3 columns.
    func pinnedColumnCount(for profileId: UUID) -> Int {
        let count = effectivePinnedCount(for: profileId)
        guard count > 0 else { return 1 }
        return count <= 4 ? count : 3
    }

    var pinnedColumnCount: Int {
        pinnedColumnCount(for: browserState.currentProfileId)
    }

    func pinnedGridColumns(for profileId: UUID) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: pinnedColumnCount(for: profileId))
    }

    private var pinnedGridColumns: [GridItem] {
        pinnedGridColumns(for: browserState.currentProfileId)
    }

    private var pinnedCardWidth: CGFloat {
        let cols = pinnedColumnCount
        return max(20, (browserState.sidebarWidth - 16 - CGFloat(cols - 1) * 8) / CGFloat(cols))
    }

    func pinnedGridHeight(for profileId: UUID) -> CGFloat {
        let count = effectivePinnedCount(for: profileId)
        if count == 0 { return 0 }
        let cols = count <= 4 ? count : 3
        let rows = (count + cols - 1) / cols
        return CGFloat(rows) * 38 + CGFloat(max(0, rows - 1)) * 8 + 10
    }

    var pinnedGridHeight: CGFloat {
        pinnedGridHeight(for: browserState.currentProfileId)
    }

    enum UnpinnedTabRow: Identifiable, Equatable {
        case single(TabItem)
        case split(TabItem, TabItem)
        case folderHeader(TabFolder)

        var id: String {
            switch self {
            case .single(let tab):
                return tab.id.uuidString
            case .split(let t1, let t2):
                return "\(t1.id.uuidString)_\(t2.id.uuidString)"
            case .folderHeader(let folder):
                return "folder_\(folder.id.uuidString)"
            }
        }

        func contains(_ tabId: UUID) -> Bool {
            switch self {
            case .single(let tab):
                return tab.id == tabId
            case .split(let t1, let t2):
                return t1.id == tabId || t2.id == tabId
            case .folderHeader:
                return false
            }
        }

        func containsAny(_ tabIds: Set<UUID>) -> Bool {
            switch self {
            case .single(let tab):
                return tabIds.contains(tab.id)
            case .split(let first, let second):
                return tabIds.contains(first.id) || tabIds.contains(second.id)
            case .folderHeader:
                return false
            }
        }

        /// Folder membership of the row's tabs (nil for headers/loose rows).
        var memberFolderId: UUID? {
            switch self {
            case .single(let tab): return tab.folderId
            case .split(let t1, _): return t1.folderId
            case .folderHeader: return nil
            }
        }
    }

    func unpinnedRows(for profileId: UUID) -> [UnpinnedTabRow] {
        let unpinned = browserState.tabs.filter { ($0.profileId ?? browserState.defaultProfileId) == profileId && !$0.isPinned }
        let profileFolders = browserState.folders.filter { ($0.profileId ?? browserState.defaultProfileId) == profileId }
        var rows: [UnpinnedTabRow] = []
        var archiveRows: [UnpinnedTabRow] = []
        var handledIds = Set<UUID>()
        var emittedFolders = Set<UUID>()

        let archiveFolder = profileFolders.first(where: { $0.isArchive })
        let archiveFolderId = archiveFolder?.id

        for tab in unpinned {
            if handledIds.contains(tab.id) {
                continue
            }

            // If tab belongs to archive folder, route to archiveRows
            if let folderId = tab.folderId, folderId == archiveFolderId, let folder = archiveFolder {
                var isCollapsed = folder.isCollapsed
                if emittedFolders.insert(folderId).inserted {
                    archiveRows.append(.folderHeader(folder))
                }
                handledIds.insert(tab.id)
                if !isCollapsed {
                    archiveRows.append(.single(tab))
                }
                continue
            }

            // Folder header renders at its first member's position; members
            // of a collapsed folder are hidden. Drag previews collapse member
            // rows only at the view layer, so the complete block stays here.
            var isCollapsed = false
            if let folderId = tab.folderId, let folder = browserState.folder(for: folderId) {
                if emittedFolders.insert(folderId).inserted {
                    rows.append(.folderHeader(folder))
                }
                isCollapsed = folder.isCollapsed
            }

            if let group = browserState.splitGroup(containing: tab.id),
               group.count == 2,
               let partnerId = group.first(where: { $0 != tab.id }),
               let partnerTab = unpinned.first(where: { $0.id == partnerId }) {
                handledIds.insert(tab.id)
                handledIds.insert(partnerId)
                if !isCollapsed {
                    let firstTab = group[0] == tab.id ? tab : partnerTab
                    let secondTab = group[0] == tab.id ? partnerTab : tab
                    rows.append(.split(firstTab, secondTab))
                }
            } else {
                handledIds.insert(tab.id)
                if !isCollapsed {
                    rows.append(.single(tab))
                }
            }
        }

        // Folders with no member tabs still render so they can receive drops and be managed.
        for folder in profileFolders where !emittedFolders.contains(folder.id) {
            if folder.isArchive {
                archiveRows.append(.folderHeader(folder))
            } else {
                rows.append(.folderHeader(folder))
            }
        }

        return rows + archiveRows
    }

    var unpinnedRows: [UnpinnedTabRow] {
        unpinnedRows(for: browserState.currentProfileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fixed top section for traffic light clearance
            WindowDragArea()
                .frame(width: browserState.sidebarWidth, height: headerHeight, alignment: .leading)

            // Multi-Space continuous horizontal strip (Pinned tabs + New tab button + Unpinned tabs)
            let sidebarWidth = browserState.sidebarWidth
            let profiles = browserState.profiles
            let currIdx = profiles.firstIndex(where: { $0.id == browserState.currentProfileId }) ?? 0
            let totalOffset = browserState.profileSwipeOffset

            HStack(spacing: 0) {
                ForEach(profiles, id: \.id) { profile in
                    let isColumnCurrent = (profile.id == browserState.currentProfileId)
                    ProfileSpaceColumnView(
                        profile: profile,
                        isCurrent: isColumnCurrent,
                        pinned: pinnedTabs(for: profile.id),
                        gridHeight: pinnedGridHeight(for: profile.id),
                        gridCols: pinnedGridColumns(for: profile.id),
                        profSelectedTabId: selectedTabId(for: profile.id),
                        profCurrentTabIds: currentTabIds(for: profile.id),
                        profActiveTabBackgroundColor: activeTabBackgroundColor(for: profile),
                        rows: unpinnedRows(for: profile.id),
                        sidebarWidth: sidebarWidth,
                        hasMultipleSelectedTabs: hasMultipleSelectedTabs,
                        selectedSidebarTabIds: browserState.selectedSidebarTabIds,
                        activeDrag: activeDrag,
                        renamingFolderId: renamingFolderId,
                        renamingTabId: renamingTabId,
                        smoothTabSwitchAnimation: smoothTabSwitchAnimation && enableMatchedGeometry,
                        tabAnimationNamespace: (smoothTabSwitchAnimation && enableMatchedGeometry && isColumnCurrent) ? tabAnimationNamespace : nil,
                        tabSelectionAnimation: tabSelectionAnimation,
                        tabMediaStates: browserState.tabMediaStates,
                        isTabThemeLight: { isTabThemeLight(for: $0) },
                        pinnedShiftOffset: { pinnedShiftOffset(for: $0) },
                        unpinnedShiftOffset: { unpinnedShiftOffset(forRowIndex: $0, in: $1) },
                        onSelectTab: { tabId in
                            let isProfileSwitch = (profile.id != browserState.currentProfileId)
                            if isProfileSwitch {
                                browserState.switchProfile(to: profile.id)
                            }

                            let prevIsUnpinned = isUnpinnedTabInCurrentProfile(browserState.selectedTabId)
                            let nextIsUnpinned = isUnpinnedTabInCurrentProfile(tabId)
                            let isSmoothSwitch = !isProfileSwitch && prevIsUnpinned && nextIsUnpinned

                            if isSmoothSwitch, let anim = tabSelectionAnimation {
                                enableMatchedGeometry = true
                                withAnimation(anim) {
                                    browserState.selectSidebarTab(tabId, extendingRange: NSEvent.modifierFlags.contains(.shift))
                                }
                            } else {
                                enableMatchedGeometry = false
                                var tx = Transaction()
                                tx.disablesAnimations = true
                                withTransaction(tx) {
                                    browserState.selectSidebarTab(tabId, extendingRange: NSEvent.modifierFlags.contains(.shift))
                                }
                                if nextIsUnpinned {
                                    DispatchQueue.main.async {
                                        enableMatchedGeometry = true
                                    }
                                }
                            }
                            previousSelectedTabId = tabId
                        },
                        onRemoveTab: { browserState.removeTab(id: $0) },
                        onToggleMuteTab: { browserState.toggleMuteTab(id: $0) },
                        onRenameTab: { id, title in
                            browserState.renameTab(id: id, to: title)
                            renamingTabId = nil
                        },
                        onOpenCommandPalette: {
                            if profile.id != browserState.currentProfileId {
                                browserState.switchProfile(to: profile.id)
                            }
                            browserState.openCommandPalette()
                        },
                        onFolderToggleCollapse: { id in
                            browserState.clearSidebarSelection()
                            browserState.toggleFolderCollapsed(id: id)
                        },
                        onFolderRename: { id, name in
                            browserState.renameFolder(id: id, to: name)
                            renamingFolderId = nil
                        },
                        onFolderClose: { browserState.requestCloseFolder(id: $0) },
                        onStartRenameFolder: { renamingFolderId = $0 },
                        onCancelRenameFolder: { renamingFolderId = nil },
                        onCancelRenameTab: { renamingTabId = nil },
                        onPinnedDragChanged: { tab, val in handleDragChanged(tab: tab, source: .pinned, value: val) },
                        onUnpinnedDragChanged: { tab, src, rowIdx, val in handleDragChanged(tab: tab, source: src, rowIndex: rowIdx, value: val) },
                        onFolderDragChanged: { fld, rowIdx, val in handleFolderDragChanged(folder: fld, rowIndex: rowIdx, value: val) },
                        onDragEnded: { handleDragEnded(value: $0) },
                        tabContextMenuBuilder: { tab in AnyView(tabContextMenu(for: tab)) },
                        folderContextMenuHost: { folder in
                            AnyView(FolderContextMenuHost(
                                folder: folder,
                                browserState: browserState,
                                onRename: { renamingFolderId = folder.id },
                                onClose: { browserState.requestCloseFolder(id: folder.id) },
                                onDelete: { browserState.deleteFolder(id: folder.id) }
                            ))
                        }
                    )
                    .equatable()
                    .frame(width: sidebarWidth, alignment: .topLeading)
                }
            }
            .frame(width: sidebarWidth * CGFloat(max(1, profiles.count)), alignment: .leading)
            .offset(x: -(CGFloat(currIdx) * sidebarWidth) + totalOffset)
            .frame(width: sidebarWidth, alignment: .leading)
            .clipped()

            // Profile Indicator Dock at the bottom
            if !browserState.isPrivate && browserState.profiles.count > 1 {
                ProfileIndicatorBar(browserState: browserState)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: isDragCollapsed ? 0 : browserState.sidebarWidth, alignment: .leading)
        .opacity(isDragCollapsed ? 0 : 1)
        .clipped()
        .overlay(alignment: .trailing) {
            resizeHandle
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(WindowDragArea())
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isDragCollapsed)
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: browserState.profiles.count > 1)
        .onAppear {
            previousSelectedTabId = browserState.selectedTabId
            enableMatchedGeometry = isUnpinnedTabInCurrentProfile(browserState.selectedTabId)
        }
        .onChange(of: browserState.selectedTabId) { oldId, newId in
            let prevIsUnpinned = isUnpinnedTabInCurrentProfile(oldId)
            let nextIsUnpinned = isUnpinnedTabInCurrentProfile(newId)
            if prevIsUnpinned && nextIsUnpinned {
                enableMatchedGeometry = true
            } else {
                enableMatchedGeometry = false
                if nextIsUnpinned {
                    DispatchQueue.main.async {
                        enableMatchedGeometry = true
                    }
                }
            }
            previousSelectedTabId = newId
        }
        .onChange(of: browserState.currentProfileId) { _, _ in
            enableMatchedGeometry = false
            if isUnpinnedTabInCurrentProfile(browserState.selectedTabId) {
                DispatchQueue.main.async {
                    enableMatchedGeometry = true
                }
            }
        }
    }

    // MARK: - Profile Space Column View (Equatable for 120fps Gesture Performance)

    struct ProfileSpaceColumnView: View, Equatable {
        let profile: Profile
        let isCurrent: Bool
        let pinned: [TabItem]
        let gridHeight: CGFloat
        let gridCols: [GridItem]
        let profSelectedTabId: UUID?
        let profCurrentTabIds: [UUID]
        let profActiveTabBackgroundColor: Color
        let rows: [Tabstrip.UnpinnedTabRow]
        let sidebarWidth: CGFloat
        let hasMultipleSelectedTabs: Bool
        let selectedSidebarTabIds: Set<UUID>
        let activeDrag: TabDragState?
        let renamingFolderId: UUID?
        let renamingTabId: UUID?
        let smoothTabSwitchAnimation: Bool
        let tabAnimationNamespace: Namespace.ID?
        let tabSelectionAnimation: Animation?
        let tabMediaStates: [UUID: TabMediaState]

        let isTabThemeLight: (UUID) -> Bool
        let pinnedShiftOffset: (UUID) -> CGSize
        let unpinnedShiftOffset: (Int, [Tabstrip.UnpinnedTabRow]) -> CGFloat

        let onSelectTab: (UUID) -> Void
        let onRemoveTab: (UUID) -> Void
        let onToggleMuteTab: (UUID) -> Void
        let onRenameTab: (UUID, String) -> Void
        let onOpenCommandPalette: () -> Void

        let onFolderToggleCollapse: (UUID) -> Void
        let onFolderRename: (UUID, String) -> Void
        let onFolderClose: (UUID) -> Void
        let onStartRenameFolder: (UUID) -> Void
        let onCancelRenameFolder: () -> Void
        let onCancelRenameTab: () -> Void

        let onPinnedDragChanged: (TabItem, DragGesture.Value) -> Void
        let onUnpinnedDragChanged: (TabItem, TabDragState.Source, Int, DragGesture.Value) -> Void
        let onFolderDragChanged: (TabFolder, Int, DragGesture.Value) -> Void
        let onDragEnded: (DragGesture.Value) -> Void

        let tabContextMenuBuilder: (TabItem) -> AnyView
        let folderContextMenuHost: (TabFolder) -> AnyView

        static func == (lhs: ProfileSpaceColumnView, rhs: ProfileSpaceColumnView) -> Bool {
            lhs.profile == rhs.profile &&
            lhs.isCurrent == rhs.isCurrent &&
            lhs.pinned == rhs.pinned &&
            lhs.gridHeight == rhs.gridHeight &&
            lhs.profSelectedTabId == rhs.profSelectedTabId &&
            lhs.profCurrentTabIds == rhs.profCurrentTabIds &&
            lhs.profActiveTabBackgroundColor == rhs.profActiveTabBackgroundColor &&
            lhs.rows == rhs.rows &&
            lhs.sidebarWidth == rhs.sidebarWidth &&
            lhs.hasMultipleSelectedTabs == rhs.hasMultipleSelectedTabs &&
            lhs.selectedSidebarTabIds == rhs.selectedSidebarTabIds &&
            lhs.activeDrag == rhs.activeDrag &&
            lhs.renamingFolderId == rhs.renamingFolderId &&
            lhs.renamingTabId == rhs.renamingTabId &&
            lhs.smoothTabSwitchAnimation == rhs.smoothTabSwitchAnimation &&
            lhs.tabMediaStates == rhs.tabMediaStates
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Pinned Tabs Grid
                VStack(spacing: 0) {
                    if gridHeight > 0 {
                        LazyVGrid(columns: gridCols, spacing: 8) {
                            ForEach(pinned, id: \.id) { tab in
                                let isBeingDragged = isCurrent && (activeDrag?.draggedTabIds.contains(tab.id) == true)

                                PinnedTabButton(
                                    tab: tab,
                                    isSelected: (profSelectedTabId == tab.id),
                                    isMultiSelected: isCurrent && hasMultipleSelectedTabs && selectedSidebarTabIds.contains(tab.id),
                                    isInSplit: profCurrentTabIds.contains(tab.id),
                                    isDraggingAnyTab: isCurrent && (activeDrag != nil),
                                    namespace: nil,
                                    isRenaming: isCurrent && (renamingTabId == tab.id),
                                    isPlayingAudio: tabMediaStates[tab.id]?.isPlayingAudio ?? false,
                                    isMuted: tabMediaStates[tab.id]?.isMuted ?? false,
                                    onToggleMute: { onToggleMuteTab(tab.id) },
                                    onCommitRename: { title in onRenameTab(tab.id, title) },
                                    onCancelRename: { onCancelRenameTab() },
                                    profileAccentColor: profile.color.color,
                                    onSelect: { onSelectTab(tab.id) }
                                )
                                .opacity(isBeingDragged ? 0.0 : 1.0)
                                .offset(isCurrent ? pinnedShiftOffset(tab.id) : .zero)
                                .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: pinnedShiftOffset(tab.id))
                                .contextMenu {
                                    tabContextMenuBuilder(tab)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                                        .onChanged { value in
                                            guard isCurrent else { return }
                                            onPinnedDragChanged(tab, value)
                                        }
                                        .onEnded { value in
                                            guard isCurrent else { return }
                                            onDragEnded(value)
                                        }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                    }
                }
                .frame(width: sidebarWidth, height: gridHeight, alignment: .topLeading)
                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: gridHeight)

                // New Tab button
                NewTabButton {
                    onOpenCommandPalette()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 1)
                .frame(width: sidebarWidth, alignment: .leading)

                // Unpinned tabs list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                            switch row {
                            case .folderHeader(let folder):
                                FolderRow(
                                    folder: folder,
                                    isRenaming: isCurrent && (renamingFolderId == folder.id),
                                    onToggleCollapse: {
                                        guard isCurrent else { return }
                                        onFolderToggleCollapse(folder.id)
                                    },
                                    onCommitRename: { name in
                                        onFolderRename(folder.id, name)
                                    },
                                    onCancelRename: {
                                        onCancelRenameFolder()
                                    },
                                    onClose: {
                                        onFolderClose(folder.id)
                                    }
                                )
                                .opacity(isCurrent && activeDrag?.folder?.id == folder.id ? 0.0 : 1.0)
                                .padding(.bottom, 3)
                                .offset(y: isCurrent ? unpinnedShiftOffset(rowIndex, rows) : 0)
                                .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: unpinnedShiftOffset(rowIndex, rows))
                                .overlay(
                                    folderContextMenuHost(folder)
                                )
                                .gesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                                        .onChanged { value in
                                            guard isCurrent else { return }
                                            onFolderDragChanged(folder, rowIndex, value)
                                        }
                                        .onEnded { value in
                                            guard isCurrent else { return }
                                            onDragEnded(value)
                                        }
                                )

                            case .single(let tab):
                                let isBeingDragged = isCurrent && activeDrag?.draggedTabIds.contains(tab.id) == true
                                let isDraggedFolderMember = isCurrent && activeDrag?.folder != nil && activeDrag?.folder?.id == tab.folderId

                                TabButton(
                                    tab: tab,
                                    isSelected: (profSelectedTabId == tab.id),
                                    isMultiSelected: isCurrent && hasMultipleSelectedTabs && selectedSidebarTabIds.contains(tab.id),
                                    isDragging: isBeingDragged,
                                    isDraggingAnyTab: isCurrent && activeDrag != nil,
                                    isThemeLight: isTabThemeLight(tab.id),
                                    activeTabBackgroundColor: profActiveTabBackgroundColor,
                                    namespace: smoothTabSwitchAnimation ? tabAnimationNamespace : nil,
                                    sidebarWidth: sidebarWidth - (tab.folderId != nil ? 14 : 0),
                                    isRenaming: isCurrent && (renamingTabId == tab.id),
                                    isPlayingAudio: tabMediaStates[tab.id]?.isPlayingAudio ?? false,
                                    isMuted: tabMediaStates[tab.id]?.isMuted ?? false,
                                    onToggleMute: { onToggleMuteTab(tab.id) },
                                    onCommitRename: { title in onRenameTab(tab.id, title) },
                                    onCancelRename: { onCancelRenameTab() },
                                    onSelect: { onSelectTab(tab.id) },
                                    onClose: { onRemoveTab(tab.id) }
                                )
                                .padding(.leading, tab.folderId != nil ? 14 : 0)
                                .opacity(isBeingDragged || isDraggedFolderMember ? 0.0 : 1.0)
                                .frame(height: isDraggedFolderMember ? 0 : nil)
                                .padding(.bottom, isDraggedFolderMember ? 0 : 3)
                                .offset(y: isCurrent ? unpinnedShiftOffset(rowIndex, rows) : 0)
                                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDraggedFolderMember)
                                .animation(activeDrag == nil ? nil : .spring(response: 0.24, dampingFraction: 0.82), value: unpinnedShiftOffset(rowIndex, rows))
                                .contextMenu {
                                    tabContextMenuBuilder(tab)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 3, coordinateSpace: .named("lotusWindow"))
                                        .onChanged { value in
                                            guard isCurrent else { return }
                                            onUnpinnedDragChanged(tab, .unpinned, rowIndex, value)
                                        }
                                        .onEnded { value in
                                            guard isCurrent else { return }
                                            onDragEnded(value)
                                        }
                                )

                            case .split(let tab1, let tab2):
                                let isBeingDragged = isCurrent && (activeDrag?.draggedTabIds.contains(tab1.id) == true || activeDrag?.draggedTabIds.contains(tab2.id) == true)
                                let isDraggedFolderMember = isCurrent && activeDrag?.folder != nil && (activeDrag?.folder?.id == tab1.folderId || activeDrag?.folder?.id == tab2.folderId)

                                SplitTabRow(
                                    tab1: tab1,
                                    tab2: tab2,
                                    selectedTabId: profSelectedTabId ?? UUID(),
                                    currentTabIds: profCurrentTabIds,
                                    sidebarWidth: sidebarWidth - (tab1.folderId != nil ? 14 : 0),
                                    isMultiSelected: isCurrent && hasMultipleSelectedTabs && (selectedSidebarTabIds.contains(tab1.id) || selectedSidebarTabIds.contains(tab2.id)),
                                    isThemeLight: isTabThemeLight(profSelectedTabId ?? tab1.id),
                                    isPlayingAudio1: tabMediaStates[tab1.id]?.isPlayingAudio ?? false,
                                    isMuted1: tabMediaStates[tab1.id]?.isMuted ?? false,
                                    isPlayingAudio2: tabMediaStates[tab2.id]?.isPlayingAudio ?? false,
                                    isMuted2: tabMediaStates[tab2.id]?.isMuted ?? false,
                                    onToggleMute: { tab in onToggleMuteTab(tab.id) },
                                    activeTabBackgroundColor: profActiveTabBackgroundColor,
                                    namespace: smoothTabSwitchAnimation ? tabAnimationNamespace : nil,
                                    activeDrag: activeDrag,
                                    isDraggingAnyTab: isCurrent && activeDrag != nil,
                                    onSelect: { tab in onSelectTab(tab.id) },
                                    onClose: { tab in onRemoveTab(tab.id) },
                                    onDragChanged: { tab, value in
                                        guard isCurrent else { return }
                                        onUnpinnedDragChanged(tab, .unpinned, rowIndex, value)
                                    },
                                    onDragEnded: { value in
                                        guard isCurrent else { return }
                                        onDragEnded(value)
                                    },
                                    contextMenuBuilder: { tab in
                                        tabContextMenuBuilder(tab)
                                    }
                                )
                                .padding(.leading, tab1.folderId != nil ? 14 : 0)
                                .opacity(isBeingDragged || isDraggedFolderMember ? 0.0 : 1.0)
                                .frame(height: isDraggedFolderMember ? 0 : nil)
                                .padding(.bottom, isDraggedFolderMember ? 0 : 3)
                                .offset(y: isCurrent ? unpinnedShiftOffset(rowIndex, rows) : 0)
                                .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isDraggedFolderMember)
                                .animation(activeDrag == nil ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: unpinnedShiftOffset(rowIndex, rows))
                            }
                        }

                        // Native window drag area in empty space below tabs
                        WindowDragArea()
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .frame(width: sidebarWidth, alignment: .topLeading)
                }
                .frame(width: sidebarWidth, alignment: .leading)
                .background(WindowDragArea())
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollContentBackground(.hidden)
            .frame(width: sidebarWidth, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func tabContextMenu(for tab: TabItem) -> some View {
        let isMulti = browserState.selectedSidebarTabIds.contains(tab.id) && browserState.selectedSidebarTabIds.count > 1
        let closeTargetIds: [UUID] = isMulti
            ? browserState.tabs.filter { browserState.selectedSidebarTabIds.contains($0.id) }.map(\.id)
            : [tab.id]
        let folderTargetIds = closeTargetIds.filter { id in
            browserState.tab(for: id)?.isPinned == false
        }

        if !isMulti {
            Button("Duplicate Tab") {
                browserState.duplicateTab(id: tab.id)
            }

            Button("Reload Tab") {
                browserState.reload(for: tab.id)
            }

            Button(tab.isMuted ? "Unmute Tab" : "Mute Tab") {
                browserState.toggleMuteTab(id: tab.id)
            }

            if tab.url != nil {
                Button("Copy Tab URL") {
                    browserState.copyTabURL(id: tab.id)
                }
            }

            Button("Move Tab to New Window") {
                browserState.moveTabToNewWindow(id: tab.id)
            }

            if !tab.isPinned && tab.id != browserState.selectedTabId && !browserState.currentTabIds.contains(tab.id) && tab.url?.isLotusPage == false {
                if tab.isSnoozed {
                    Button("Wake Tab") {
                        browserState.wakeTab(id: tab.id)
                    }
                } else {
                    Button("Snooze Tab") {
                        browserState.snoozeTab(id: tab.id)
                    }
                }
            }

            Divider()
        }

        if browserState.isSplit(id: tab.id) {
            Button("Separate Views") {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    browserState.closeSplit(id: tab.id)
                }
            }
        } else {
            if !isMulti && browserState.canOpenInSplit(id: tab.id) {
                Button("Split View with Current Tab") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        browserState.openInSplit(id: tab.id)
                    }
                }
            }

            if !isMulti {
                Button("Rename…") {
                    renamingTabId = tab.id
                }

                Button(tab.isPinned ? "Unpin" : "Pin") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        browserState.togglePin(id: tab.id)
                    }
                }
            }
        }

        if !tab.isPinned {
            Divider()

            let currentTabProfileId = tab.profileId ?? browserState.defaultProfileId
            let archiveId = browserState.folders.first(where: { $0.isArchive && ($0.profileId ?? browserState.defaultProfileId) == currentTabProfileId })?.id
            let isAlreadyArchived = (tab.folderId == archiveId && archiveId != nil)

            if !isAlreadyArchived {
                let archiveTitle = isMulti && closeTargetIds.count > 1 ? "Archive \(closeTargetIds.count) Tabs" : "Archive Tab"
                Button(archiveTitle) {
                    browserState.archiveTabs(closeTargetIds)
                }
            }

            let count = folderTargetIds.count
            let moveTitle = count > 1 ? "Move \(count) Tabs to Folder" : "Move to Folder"
            let newFolderTitle = count > 1 ? "New Folder with \(count) Tabs" : "New Folder with Tab"
            let removeTitle = count > 1 ? "Remove \(count) Tabs from Folder" : "Remove from Folder"

            Menu(moveTitle) {
                Button(newFolderTitle) {
                    browserState.createFolder(with: folderTargetIds)
                }

                if !browserState.folders.isEmpty {
                    Divider()
                }
                
                ForEach(browserState.folders) { folder in
                    Button(folder.name) {
                        browserState.moveTabs(folderTargetIds, toFolder: folder.id)
                    }
                    .disabled(folderTargetIds.allSatisfy { browserState.tab(for: $0)?.folderId == folder.id })
                }
            }

            if folderTargetIds.contains(where: { browserState.tab(for: $0)?.folderId != nil }) {
                Button(removeTitle) {
                    browserState.moveTabs(folderTargetIds, toFolder: nil)
                }
            }

            if !isMulti {
                Divider()

                Button("Close Other Tabs") {
                    browserState.closeOtherTabs(id: tab.id)
                }

                Button("Close Tabs Below") {
                    browserState.closeTabsBelow(id: tab.id)
                }
            }
        }

        if browserState.profiles.count > 1 {
            let currentTabProfileId = tab.profileId ?? browserState.defaultProfileId
            let otherProfiles = browserState.profiles.filter { $0.id != currentTabProfileId }
            if !otherProfiles.isEmpty {
                Divider()
                let moveProfileTitle = isMulti && closeTargetIds.count > 1 ? "Move \(closeTargetIds.count) Tabs to Profile" : "Move to Profile"
                Menu(moveProfileTitle) {
                    ForEach(otherProfiles) { profile in
                        Button {
                            browserState.moveTabs(closeTargetIds, toProfile: profile.id)
                        } label: {
                            Label(profile.name, systemImage: profile.icon)
                        }
                    }
                }
            }
        }

        Divider()

        let closeTitle = isMulti && closeTargetIds.count > 1 ? "Close \(closeTargetIds.count) Tabs" : "Close"
        Button(closeTitle, role: .destructive) {
            for id in closeTargetIds {
                browserState.removeTab(id: id)
            }
        }
    }
}


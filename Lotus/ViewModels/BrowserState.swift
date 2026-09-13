//
//  BrowserState.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit
import Combine

/// The single observable controller owning all browser state.
///
/// Behavior is organized across focused extensions:
/// - `BrowserState+Tabs` — tab CRUD, selection, pinning, reopen
/// - `BrowserState+WebViews` — per-tab WKWebView lifecycle and KVO observers
/// - `BrowserState+Navigation` — WKNavigationDelegate and navigation actions
/// - `BrowserState+UIDelegate` — WKUIDelegate and script messages
/// - `BrowserState+Theming` — favicon/page theme color extraction
/// - `BrowserState+SessionPersistence` — session save/restore
/// - `BrowserState+Quit` — quit confirmation flow
final class BrowserState: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    // MARK: - Published State

    @Published var tabs: [TabItem] {
        didSet {
            saveSession()
            scheduleAutomaticFolderNames(affectedBy: oldValue)
        }
    }
    @Published var selectedTabId: UUID {
        didSet {
            if isZapModeActive {
                stopZapMode(for: oldValue)
            }
            wakeTab(id: selectedTabId)
            if let tab = tabs.first(where: { $0.id == selectedTabId }) {
                let profId = tab.profileId ?? defaultProfileId
                lastSelectedTabPerProfile[profId] = selectedTabId
            }
            updateNavigationState()
            syncFocusStateForActiveTab()
            handlePictureInPictureOnTabSwitch(from: oldValue, to: selectedTabId)
            syncFindOnTabSwitch(from: oldValue, to: selectedTabId)
            updateLastViewedTimestamp(for: selectedTabId)
            archiveInactiveTabsIfNeeded()
            snoozeInactiveTabsIfNeeded()
            saveSession()
        }
    }
    @Published var currentTabIds: [UUID] {
        didSet {
            if let firstId = currentTabIds.first, let tab = tabs.first(where: { $0.id == firstId }) {
                let profId = tab.profileId ?? defaultProfileId
                lastCurrentTabsPerProfile[profId] = currentTabIds
            }
            if !currentTabIds.contains(selectedTabId), let first = currentTabIds.first {
                selectedTabId = first
            }
            updateNavigationState()
            syncFocusStateForActiveTab()
            saveSession()
        }
    }
    @Published var splitGroups: [[UUID]] = [] {
        didSet {
            saveSession()
        }
    }
    @Published var splitRatios: [String: CGFloat] = [:] {
        didSet {
            saveSession()
        }
    }
    @Published var isResizingSplit: Bool = false
    @Published var folders: [TabFolder] = [] {
        didSet {
            saveSession()
        }
    }
    @Published var isSidebarVisible: Bool = true {
        didSet {
            saveSession()
        }
    }
    @Published var sidebarWidth: CGFloat = 240 {
        didSet {
            saveSession()
        }
    }
    @Published var isResizingSidebar: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    /// Navigation state for every live webview. Split-pane chrome observes
    /// these values instead of reading non-observable WKWebView properties.
    @Published var tabLoadingStates: [UUID: Bool] = [:]
    @Published var tabEstimatedProgress: [UUID: Double] = [:]
    @Published var activeThemeColor: Color? = nil
    @Published var activeThemeNSColor: NSColor? = nil
    @Published var isThemeLight: Bool = false
    @Published var isWebInputFocused: Bool = false
    @Published var isQuitConfirmationPresented: Bool = false
    @Published var folderToCloseConfirmation: UUID? = nil
    var onOpenNewWindow: ((URL, Bool) -> Void)?

    func requestOpenNewWindow(url: URL, isPrivate: Bool = false) {
        onOpenNewWindow?(url, isPrivate)
    }
    @Published var profileToDeleteConfirmation: Profile? = nil
    @Published var profileToEdit: Profile? = nil
    @Published var isCreatingProfile: Bool = false
    @Published var deleteBangConfirmation: CustomBang? = nil
    @Published var historyConfirmation: HistoryConfirmationType? = nil
    @Published var downloadConfirmation: DownloadConfirmationType? = nil
    @Published var bookmarkConfirmation: BookmarkConfirmationType? = nil
    @Published var websiteDataConfirmation: WebsiteDataConfirmationType? = nil
    @Published var activeJavaScriptDialog: JavaScriptDialogRequest? = nil
    var pendingJavaScriptDialogs: [JavaScriptDialogRequest] = []
    @Published var profileTransitionDirection: ProfileTransitionDirection = .forward
    @Published var profileSwipeOffset: CGFloat = 0
    @Published var lastSelectedTabPerProfile: [UUID: UUID] = [:]
    @Published var lastCurrentTabsPerProfile: [UUID: [UUID]] = [:]
    @Published var isClearAllDataConfirmationPresented: Bool = false
    @Published var isCommandPaletteOpen: Bool = false
    @Published var commandPaletteMode: CommandPaletteMode = .newTab
    @Published var isFindPresented: Bool = false
    @Published var findQuery: String = ""
    @Published var findCurrentMatch: Int = 0
    @Published var findTotalMatches: Int = 0
    @Published var findFocusTrigger: Int = 0
    @Published var focusAddressBarTabId: UUID? = nil
    @Published var urlCopyFeedback: URLCopyFeedback? = nil
    @Published var activeTabDrag: TabDragState? = nil
    @Published var selectedSidebarTabIds: Set<UUID> = []
    var sidebarSelectionAnchorId: UUID? = nil
    @Published var tabZoomLevels: [UUID: CGFloat] = [:] {
        didSet {
            saveSession()
        }
    }
    @Published var lastZoomChangeDirection: [UUID: Bool] = [:]
    @Published var pageLoadErrors: [UUID: PageLoadError] = [:]
    @Published var httpAllowedDomains: Set<String> = []
    @Published var tabMediaStates: [UUID: TabMediaState] = [:]
    @Published var isZapModeActive: Bool = false
    @Published var lastZappedElement: ZappedElement? = nil
    @Published var wakingTabIds: Set<UUID> = []
    var tabServerTrusts: [UUID: SecTrust] = [:]
    let isPrivate: Bool


    static let zoomSteps: [CGFloat] = [
        0.50, 0.67, 0.75, 0.80, 0.90, 1.0, 1.10, 1.25, 1.50, 1.75, 2.0, 2.50, 3.0
    ]

    func zoomLevel(for tabId: UUID? = nil) -> CGFloat {
        let id = tabId ?? selectedTabId
        if url(for: id)?.isLotusPage == true {
            return 1.0
        }
        return tabZoomLevels[id] ?? 1.0
    }

    func setZoomLevel(_ level: CGFloat, for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        guard url(for: id)?.isLotusPage != true else { return }
        let clamped = min(3.0, max(0.5, (round(level * 100) / 100)))
        let previous = tabZoomLevels[id] ?? 1.0
        lastZoomChangeDirection[id] = clamped >= previous
        tabZoomLevels[id] = clamped
        if let webView = webViewStore[id] {
            webView.pageZoom = clamped
        }
    }

    func zoomIn(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        let current = zoomLevel(for: id)
        if let next = Self.zoomSteps.first(where: { $0 > current + 0.01 }) {
            setZoomLevel(next, for: id)
        } else {
            setZoomLevel(min(3.0, current + 0.25), for: id)
        }
    }

    func zoomOut(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        let current = zoomLevel(for: id)
        if let prev = Self.zoomSteps.last(where: { $0 < current - 0.01 }) {
            setZoomLevel(prev, for: id)
        } else {
            setZoomLevel(max(0.5, current - 0.25), for: id)
        }
    }

    func resetZoom(for tabId: UUID? = nil) {
        let id = tabId ?? selectedTabId
        setZoomLevel(1.0, for: id)
    }

    func focusAddressBar(for tabId: UUID? = nil) {
        focusAddressBarTabId = tabId ?? selectedTabId
    }

    // MARK: - Recently Closed

    /// LIFO stack of recently closed tabs (capped at `maxRecentlyClosed`).
    var recentlyClosed: [ClosedTabRecord] = []
    let maxRecentlyClosed = 20

    // MARK: - Services & Stores

    let profileStore = ProfileStore()
    @Published var profiles: [Profile] = []
    @Published var currentProfileId: UUID
    let sessionStore = SessionStore()
    let historyStore = HistoryStore()
    @Published var historyEntries: [HistoryItem] = []
    let downloadStore = DownloadStore()
    @Published var downloads: [DownloadItem] = [] {
        didSet {
            updateDockProgress()
        }
    }
    let bookmarkStore = BookmarkStore()
    @Published var bookmarks: [BookmarkItem] = []
    @Published var activeFlyingDownload: FlyingDownloadPayload? = nil
    @Published var downloadsButtonCenter: CGPoint? = nil
    @Published var isDownloadsButtonVisibleInToolbar: Bool = false
    @Published var downloadCatchPulseTrigger: Int = 0
    @Published var themeBloomTrigger: [UUID: Int] = [:]
    @Published var shieldDeflectTrigger: [UUID: Int] = [:]
    private var lastShieldDeflectTime: [UUID: Date] = [:]

    var isDownloadsConfiguredInToolbar: Bool {
        let raw = UserDefaults.standard.string(forKey: "lotus.browser.toolbarLayout") ?? ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)
        let items = ToolbarItemType.parseLayout(from: raw)
        return items.contains(.downloads)
    }

    func triggerShieldDeflect(for tabId: UUID) {
        let now = Date()
        if let last = lastShieldDeflectTime[tabId], now.timeIntervalSince(last) < 1.0 {
            return
        }
        lastShieldDeflectTime[tabId] = now
        shieldDeflectTrigger[tabId, default: 0] += 1
    }
    var customDownloadDirectory: URL?
    var urlCopyFeedbackDismissalWorkItem: DispatchWorkItem?

    var activeDownloadsCount: Int {
        downloads.filter { $0.state == .downloading }.count
    }

    var hasActiveDownloads: Bool {
        activeDownloadsCount > 0
    }

    var overallDownloadProgress: Double {
        let active = downloads.filter { $0.state == .downloading }
        guard !active.isEmpty else { return 0.0 }
        let totalFraction = active.reduce(0.0) { $0 + $1.progressFraction }
        return totalFraction / Double(active.count)
    }

    var lastContextMenuImageURL: URL?
    var lastContextMenuLinkURL: URL?
    var lastContextMenuSelectedText: String?

    func triggerFlyingDownloadAnimation(filename: String, iconName: String, startLocation: CGPoint? = nil) {
        guard isDownloadsConfiguredInToolbar else { return }
        let start = startLocation ?? FlyingDownloadView.currentMouseWindowLocation()
        let tab = activeTab
        let faviconColors = tab?.faviconURL.flatMap { FaviconColorExtractor.shared.colors(for: $0) }
        let faviconColor = tab?.faviconURL.flatMap { FaviconColorExtractor.shared.color(for: $0) } ?? activeThemeColor
        let isLight = isThemeLight
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloadsConfiguredInToolbar else { return }
            self.activeFlyingDownload = FlyingDownloadPayload(
                filename: filename,
                iconName: iconName,
                startPoint: start,
                themeColor: faviconColor,
                gradientColors: faviconColors,
                isThemeLight: isLight
            )
        }
    }

    var pendingSaveWorkItem: DispatchWorkItem?
    let saveDebounceInterval: TimeInterval = 0.5
    var automaticFolderNameTasks: [UUID: Task<Void, Never>] = [:]
    var automaticFolderNameGenerationIDs: [UUID: UUID] = [:]
    var automaticFolderNameLastGeneratedInputs: [UUID: AutomaticFolderNameInput] = [:]

    var terminationObserver: NSObjectProtocol?
    private var keyMonitor: Any?

    static let alwaysQuitKey = "lotus.always_quit_without_confirming"
    static let autoFolderNamesKey = "lotus.browser.autoFolderNames"

    var isAutoFolderNamesEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.autoFolderNamesKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: Self.autoFolderNamesKey)
    }

    /// Tabs whose playing video was auto-detached into Picture in Picture
    /// when the user switched away (see `BrowserState+PictureInPicture`).
    var autoPiPTabs: Set<UUID> = []

    var themeColors: [UUID: ParsedThemeColor] = [:]
    var webViewStore: [UUID: WKWebView] = [:]
    var observers: [UUID: [NSKeyValueObservation]] = [:]

    // MARK: - Focus

    var isAnyTextInputFocused: Bool {
        if isCommandPaletteOpen || isFindPresented || folderToCloseConfirmation != nil || isQuitConfirmationPresented || isClearAllDataConfirmationPresented || profileToDeleteConfirmation != nil || deleteBangConfirmation != nil || historyConfirmation != nil || downloadConfirmation != nil || bookmarkConfirmation != nil || websiteDataConfirmation != nil || activeJavaScriptDialog != nil || profileToEdit != nil || isCreatingProfile {
            return true
        }
        if let responder = NSApp.keyWindow?.firstResponder {
            if responder is NSTextView || responder is NSTextField {
                return true
            }
        }
        return isWebInputFocused
    }

    // MARK: - JavaScript Dialogs

    func presentJavaScriptDialog(_ request: JavaScriptDialogRequest) {
        if activeJavaScriptDialog == nil {
            activeJavaScriptDialog = request
        } else {
            pendingJavaScriptDialogs.append(request)
        }
    }

    func dismissJavaScriptDialog() {
        activeJavaScriptDialog = nil
        if !pendingJavaScriptDialogs.isEmpty {
            activeJavaScriptDialog = pendingJavaScriptDialogs.removeFirst()
        }
    }

    // MARK: - Lifecycle

    init(tabs: [TabItem]? = nil, initialSelectedId: UUID? = nil, isPrivate: Bool = false) {
        self.isPrivate = isPrivate
        let pStore = ProfileStore()
        let loadedProfiles = isPrivate ? [Profile.defaultProfile] : pStore.load()
        self.profiles = loadedProfiles
        let defaultProfId = loadedProfiles.first(where: { $0.isDefault })?.id ?? Profile.defaultProfileId
        let store = SessionStore()
        let restoredSession = (!isPrivate && tabs == nil) ? store.load() : nil
        let startupBehavior = isPrivate ? "empty" : (UserDefaults.standard.string(forKey: "lotus.browser.startupBehavior") ?? "restore")

        let activeProfId: UUID
        if isPrivate {
            activeProfId = Profile.defaultProfileId
        } else if let savedId = restoredSession?.currentProfileId, loadedProfiles.contains(where: { $0.id == savedId }) {
            activeProfId = savedId
        } else {
            activeProfId = defaultProfId
        }
        self.currentProfileId = activeProfId
        if !isPrivate, let currentProf = loadedProfiles.first(where: { $0.id == activeProfId }) {
            UserDefaults.standard.set(currentProf.color.accentColorEquivalent.rawValue, forKey: "lotus.browser.accentColor")
        }

        if isPrivate {
            self.tabs = []
            self.folders = []
            self.selectedTabId = UUID()
            self.splitGroups = []
            self.currentTabIds = []
            self.isCommandPaletteOpen = true
        } else if let explicitTabs = tabs {
            let normalizedTabs = explicitTabs.map { tab -> TabItem in
                var t = tab
                if t.profileId == nil { t.profileId = activeProfId }
                return t
            }
            self.tabs = normalizedTabs
            let sel = initialSelectedId ?? normalizedTabs.first?.id ?? UUID()
            self.selectedTabId = sel
            self.splitGroups = []
            self.currentTabIds = [sel]
        } else if startupBehavior == "empty" {
            self.tabs = []
            self.folders = []
            self.selectedTabId = UUID()
            self.splitGroups = []
            self.currentTabIds = []
            self.isCommandPaletteOpen = true
        } else if let session = restoredSession {
            // Migration: the lotus://newtab page no longer exists — drop any
            // blank new-tab pages persisted by older versions.
            var restoredTabs = session.tabs.filter { !($0.url?.isLotusPage == true && $0.url?.host != "history") }
            
            if startupBehavior == "pinnedOnly" {
                restoredTabs = restoredTabs.filter { $0.isPinned }
            }

            // Restore folders; clear membership that points at a missing
            // folder, and never let pinned tabs carry folder membership.
            let rawFolders = (startupBehavior == "pinnedOnly") ? [] : (session.folders ?? [])
            let restoredFolders = rawFolders.map { folder -> TabFolder in
                var f = folder
                if f.profileId == nil { f.profileId = defaultProfId }
                return f
            }
            let folderIds = Set(restoredFolders.map { $0.id })
            restoredTabs = restoredTabs.map { tab in
                var tab = tab
                if tab.profileId == nil {
                    tab.profileId = defaultProfId
                }
                if let folderId = tab.folderId, !folderIds.contains(folderId) || tab.isPinned {
                    tab.folderId = nil
                }
                return tab
            }
            self.folders = restoredFolders
            self.tabs = restoredTabs
            let sel = restoredTabs.contains(where: { $0.id == session.selectedTabId }) ? session.selectedTabId : (restoredTabs.first(where: { ($0.profileId ?? defaultProfId) == activeProfId })?.id ?? restoredTabs.first?.id ?? UUID())
            self.selectedTabId = sel
            let validTabsSet = Set(restoredTabs.map { $0.id })
            let validGroups = (startupBehavior == "pinnedOnly") ? [] : (session.splitGroups ?? []).map { group in
                group.filter { validTabsSet.contains($0) }
            }.filter { $0.count >= 2 }
            self.splitGroups = validGroups
            self.splitRatios = (startupBehavior == "pinnedOnly") ? [:] : (session.splitRatios ?? [:])
            if restoredTabs.isEmpty {
                self.currentTabIds = []
                self.isCommandPaletteOpen = true
            } else if let saved = session.currentTabIds, saved.count >= 2, startupBehavior != "pinnedOnly" {
                let valid = saved.filter { validTabsSet.contains($0) }
                self.currentTabIds = valid.isEmpty ? [sel] : valid
            } else if let group = validGroups.first(where: { $0.contains(sel) }) {
                self.currentTabIds = group
            } else {
                self.currentTabIds = [sel]
            }
            self.recentlyClosed = session.recentlyClosed.map { rec in
                var r = rec
                if r.profileId == nil { r.profileId = defaultProfId }
                return r
            }
            self.isSidebarVisible = session.isSidebarVisible
            self.sidebarWidth = session.sidebarWidth
            if let savedZooms = session.tabZoomLevels {
                var loadedZooms: [UUID: CGFloat] = [:]
                for (key, val) in savedZooms {
                    if let uuid = UUID(uuidString: key), validTabsSet.contains(uuid) {
                        loadedZooms[uuid] = val
                    }
                }
                self.tabZoomLevels = loadedZooms
            }
            if let savedSelected = session.lastSelectedTabPerProfile {
                var loaded: [UUID: UUID] = [:]
                for (key, val) in savedSelected {
                    if let profUUID = UUID(uuidString: key), validTabsSet.contains(val) {
                        loaded[profUUID] = val
                    }
                }
                self.lastSelectedTabPerProfile = loaded
            }
            if let savedCurrents = session.lastCurrentTabsPerProfile {
                var loaded: [UUID: [UUID]] = [:]
                for (key, val) in savedCurrents {
                    if let profUUID = UUID(uuidString: key) {
                        let filtered = val.filter { validTabsSet.contains($0) }
                        if !filtered.isEmpty {
                            loaded[profUUID] = filtered
                        }
                    }
                }
                self.lastCurrentTabsPerProfile = loaded
            }
        } else {
            let sampleTabs = TabItem.samples.map { tab -> TabItem in
                var t = tab
                t.profileId = defaultProfId
                return t
            }
            self.tabs = sampleTabs
            let sel = sampleTabs.first?.id ?? UUID()
            self.selectedTabId = sel
            self.splitGroups = []
            self.currentTabIds = [sel]
        }
        super.init()
        self.historyEntries = historyStore.load()
        self.downloads = downloadStore.load()
        self.bookmarks = bookmarkStore.load()
        self.restoreDownloadLocation()
        self.updateNavigationState()
        // Initialize webviews for the currently visible tab(s) so they begin loading immediately
        for tabId in currentTabIds {
            _ = getWebView(for: tabId)
        }
        self.setupTerminationObserver()
        self.setupKeyMonitor()
        self.setupScrollMonitor()
    }

    deinit {
        urlCopyFeedbackDismissalWorkItem?.cancel()
        customDownloadDirectory?.stopAccessingSecurityScopedResource()
        if let obs = terminationObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if let km = keyMonitor {
            NSEvent.removeMonitor(km)
        }
        if let sm = scrollMonitor {
            NSEvent.removeMonitor(sm)
        }
    }

    // MARK: - Granular Website Data Management

    /// Fetches all stored website data records (cookies, cache, localStorage, IndexedDB) from WebKit.
    func fetchWebsiteDataRecords(completion: @escaping ([WKWebsiteDataRecord]) -> Void) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { records in
            DispatchQueue.main.async {
                completion(records)
            }
        }
    }

    /// Removes data for specific website data records.
    func removeWebsiteData(records: [WKWebsiteDataRecord], completion: (() -> Void)? = nil) {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(ofTypes: types, for: records) {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    /// Removes cookies and stored data for a specific domain host name.
    func removeWebsiteData(for host: String, completion: (() -> Void)? = nil) {
        let cleanHost = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let domainOnly = cleanHost.hasPrefix("www.") ? String(cleanHost.dropFirst(4)) : cleanHost
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: types) { [weak self] records in
            let matched = records.filter { record in
                let recordHost = record.displayName.lowercased()
                return recordHost == cleanHost || recordHost == domainOnly || recordHost.hasSuffix("." + domainOnly)
            }
            guard !matched.isEmpty else {
                DispatchQueue.main.async { completion?() }
                return
            }
            WKWebsiteDataStore.default().removeData(ofTypes: types, for: matched) {
                DispatchQueue.main.async {
                    if let activeWV = self?.webViewStore[self?.selectedTabId ?? UUID()],
                       let url = activeWV.url, url.host?.lowercased().contains(domainOnly) == true {
                        activeWV.reload()
                    }
                    completion?()
                }
            }
        }
    }

    // MARK: - Clear All Data

    /// Clears all browsing data: WebKit website data (cookies, cache, IndexedDB, local storage, WebAuthn credentials),
    /// browsing history, downloads records, and favicon/color caches.
    func clearAllBrowserData(completion: (() -> Void)? = nil) {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let sinceDate = Date.distantPast
        WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: sinceDate) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else {
                    completion?()
                    return
                }

                self.historyStore.clearAll(entries: &self.historyEntries)
                self.downloadStore.clearAll(entries: &self.downloads)
                FaviconColorExtractor.shared.clearCache()

                for webView in self.webViewStore.values {
                    webView.reload()
                }

                completion?()
            }
        }
    }

    // MARK: - Key Monitor

    private func setupKeyMonitor() {
        LotusShortcuts.debugAssertNoConflicts()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return KeyboardShortcutRouter.handleKeyEvent(event, browserState: self)
        }
    }

    // MARK: - Scroll / Trackpad Profile Gesture Monitor

    private var scrollMonitor: Any? = nil
    private var horizontalScrollAccumulator: CGFloat = 0
    private var isTrackpadSwipingProfiles: Bool = false
    private var hasSwitchedInCurrentGesture: Bool = false
    private var lastProfileSwipeTime: Date = Date.distantPast

    private func setupScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self else { return event }
            guard !self.isPrivate && self.profiles.count > 1 else { return event }

            guard let window = event.window ?? NSApp.keyWindow else { return event }
            let mouseLoc = event.locationInWindow
            let sidebarWidth = self.sidebarWidth
            let isInsideSidebar = mouseLoc.x >= 0 && mouseLoc.x <= (sidebarWidth + 24) && mouseLoc.y >= 0 && mouseLoc.y <= window.frame.height

            if !self.isTrackpadSwipingProfiles && !isInsideSidebar {
                return event
            }

            let deltaX: CGFloat = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : (event.deltaX * 10)
            let deltaY: CGFloat = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : (event.deltaY * 10)

            // Has gesture phases (Trackpad continuous scroll)
            if !event.phase.isEmpty {
                if event.phase.contains(.began) {
                    self.horizontalScrollAccumulator = 0
                    self.isTrackpadSwipingProfiles = false
                    self.hasSwitchedInCurrentGesture = false
                }

                if event.phase.contains(.changed) {
                    guard !self.hasSwitchedInCurrentGesture else {
                        return nil
                    }

                    if !self.isTrackpadSwipingProfiles && abs(deltaX) > abs(deltaY) * 1.15 && abs(deltaX) > 0.8 {
                        self.isTrackpadSwipingProfiles = true
                    }

                    if self.isTrackpadSwipingProfiles {
                        self.horizontalScrollAccumulator += deltaX

                        let profiles = self.profiles
                        let currIdx = profiles.firstIndex(where: { $0.id == self.currentProfileId }) ?? 0
                        let isAtLeadingEdge = (currIdx == 0 && self.horizontalScrollAccumulator > 0)
                        let isAtTrailingEdge = (currIdx == profiles.count - 1 && self.horizontalScrollAccumulator < 0)

                        let rawOffset: CGFloat = (isAtLeadingEdge || isAtTrailingEdge)
                            ? (self.horizontalScrollAccumulator * 0.25)
                            : self.horizontalScrollAccumulator

                        // Strictly clamp between -sidebarWidth and +sidebarWidth (1 space distance max)
                        let clampedOffset = max(-sidebarWidth, min(sidebarWidth, rawOffset))
                        self.profileSwipeOffset = clampedOffset
                        return nil
                    }
                }

                if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                    if self.isTrackpadSwipingProfiles && !self.hasSwitchedInCurrentGesture {
                        let finalAccum = self.horizontalScrollAccumulator
                        self.horizontalScrollAccumulator = 0
                        self.isTrackpadSwipingProfiles = false
                        self.hasSwitchedInCurrentGesture = true

                        let threshold: CGFloat = 45.0
                        let profiles = self.profiles
                        let currIdx = profiles.firstIndex(where: { $0.id == self.currentProfileId }) ?? 0

                        if finalAccum < -threshold && currIdx + 1 < profiles.count {
                            let currentOffset = self.profileSwipeOffset
                            self.profileSwipeOffset = currentOffset + sidebarWidth
                            self.switchProfile(to: profiles[currIdx + 1].id, animated: false)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                self.profileSwipeOffset = 0
                            }
                        } else if finalAccum > threshold && currIdx > 0 {
                            let currentOffset = self.profileSwipeOffset
                            self.profileSwipeOffset = currentOffset - sidebarWidth
                            self.switchProfile(to: profiles[currIdx - 1].id, animated: false)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                self.profileSwipeOffset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                self.profileSwipeOffset = 0
                            }
                        }
                        return nil
                    }
                    self.horizontalScrollAccumulator = 0
                    self.isTrackpadSwipingProfiles = false
                    self.hasSwitchedInCurrentGesture = false
                }
            } else if !event.momentumPhase.isEmpty {
                // 2. Trackpad Momentum Phase (user lifted fingers, trackpad coasting)
                // Swallow momentum events so they do not skip past spaces or trigger duplicate transitions
                if self.isTrackpadSwipingProfiles || self.hasSwitchedInCurrentGesture {
                    if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) {
                        self.hasSwitchedInCurrentGesture = false
                        self.isTrackpadSwipingProfiles = false
                    }
                    return nil
                }
            } else {
                // 3. Discrete Mouse Wheel (notched physical wheel, no gesture phases)
                if !event.hasPreciseScrollingDeltas && abs(deltaX) > abs(deltaY) * 1.5 && abs(deltaX) > 4.0 {
                    let now = Date()
                    if now.timeIntervalSince(self.lastProfileSwipeTime) > 0.45 {
                        let profiles = self.profiles
                        let currIdx = profiles.firstIndex(where: { $0.id == self.currentProfileId }) ?? 0
                        if deltaX < -8 && currIdx + 1 < profiles.count {
                            self.lastProfileSwipeTime = now
                            DispatchQueue.main.async {
                                self.switchToNextProfile()
                            }
                            return nil
                        } else if deltaX > 8 && currIdx > 0 {
                            self.lastProfileSwipeTime = now
                            DispatchQueue.main.async {
                                self.switchToPreviousProfile()
                            }
                            return nil
                        }
                    }
                }
            }

            return event
        }
    }
}

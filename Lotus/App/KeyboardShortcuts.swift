//
//  KeyboardShortcuts.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

/// A single declarative entry in the app-wide keyboard shortcut table.
///
/// Every keyboard shortcut in Lotus must be registered here so that conflicts
/// are visible in one place. Entries are consumed by two routes:
/// - `GlobalShortcutHandlers` renders each entry as an invisible SwiftUI
///   `Button` (the standard pattern for in-window shortcuts).
/// - `BrowserState`'s `NSEvent` monitor routes matching key-down events
///   through the same table for entries with `usesEventMonitor == true`
///   (shortcuts SwiftUI can't reliably intercept while web content is
///   first responder).
struct LotusShortcut: Identifiable {
    let id: String
    let key: KeyEquivalent
    let modifiers: EventModifiers
    /// Skipped when a text field / web input is first responder.
    let guardsTextInput: Bool
    /// Routed through BrowserState's NSEvent key-down monitor instead of
    /// (or in addition to) an invisible SwiftUI button.
    let usesEventMonitor: Bool
    let action: (BrowserState) -> Void

    init(
        _ id: String,
        key: KeyEquivalent,
        modifiers: EventModifiers,
        guardsTextInput: Bool = false,
        usesEventMonitor: Bool = false,
        action: @escaping (BrowserState) -> Void
    ) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.guardsTextInput = guardsTextInput
        self.usesEventMonitor = usesEventMonitor
        self.action = action
    }

    var effectiveKey: KeyEquivalent {
        if let custom = ShortcutManager.shared.customShortcut(for: id) {
            return custom.keyEquivalent
        }
        return key
    }

    var effectiveModifiers: EventModifiers {
        if let custom = ShortcutManager.shared.customShortcut(for: id) {
            return custom.eventModifiers
        }
        return modifiers
    }

    var displayString: String {
        if let custom = ShortcutManager.shared.customShortcut(for: id) {
            return custom.displayString
        }
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("^") }
        switch key {
        case .leftArrow: parts.append("←")
        case .rightArrow: parts.append("→")
        case .tab: parts.append("⇥")
        default: parts.append(String(key.character).uppercased())
        }
        return parts.joined()
    }
}

// MARK: - Shortcut Table

/// The single source of truth for all Lotus keyboard shortcuts.
enum LotusShortcuts {

    private static func animated(_ perform: @escaping (BrowserState) -> Void) -> (BrowserState) -> Void {
        { state in
            withAnimation(.spring(response: 0.20, dampingFraction: 0.86, blendDuration: 0.02)) {
                perform(state)
            }
        }
    }

    static let table: [LotusShortcut] = [
        // MARK: Window & Tabs
        LotusShortcut("toggleSidebar", key: "s", modifiers: .command) {
            $0.toggleSidebar()
        },
        LotusShortcut("newTab", key: "t", modifiers: .command) {
            $0.toggleCommandPalette()
        },
        LotusShortcut("openSettings", key: ",", modifiers: .command, usesEventMonitor: true) {
            $0.openSettingsPage()
        },
        LotusShortcut("closeTab", key: "w", modifiers: .command, action: animated {
            $0.removeTab(id: $0.selectedTabId)
        }),
        LotusShortcut("archiveTab", key: "e", modifiers: [.command, .shift], action: animated {
            $0.archiveTab(id: $0.selectedTabId)
        }),
        LotusShortcut("reopenClosedTab", key: "t", modifiers: [.command, .shift]) {
            $0.reopenLastClosedTab()
        },
        LotusShortcut("showHistory", key: "y", modifiers: .command) {
            $0.addTabBelow(title: "History", url: .lotusHistory)
        },
        LotusShortcut("showDownloads", key: "l", modifiers: [.command, .option]) {
            $0.addTabBelow(title: "Downloads", url: .lotusDownloads)
        },
        LotusShortcut("showBookmarks", key: "b", modifiers: [.command, .option]) {
            $0.addTabBelow(title: "Bookmarks", url: .lotusBookmarks)
        },
        LotusShortcut("bookmarkPage", key: "d", modifiers: .command, usesEventMonitor: true) {
            $0.toggleBookmark()
        },

        // MARK: Navigation
        LotusShortcut("focusAddressBar", key: "l", modifiers: .command, usesEventMonitor: true) {
            $0.openCommandPaletteForCurrentTab()
        },
        LotusShortcut("copyCurrentURL", key: "c", modifiers: [.command, .shift], usesEventMonitor: true) {
            $0.copyCurrentPageURL()
        },
        LotusShortcut("findInPage", key: "f", modifiers: .command, usesEventMonitor: true) {
            $0.toggleFind()
        },
        LotusShortcut("findNext", key: "g", modifiers: .command, usesEventMonitor: true) {
            $0.findNext()
        },
        LotusShortcut("findPrevious", key: "g", modifiers: [.command, .shift], usesEventMonitor: true) {
            $0.findPrevious()
        },
        LotusShortcut("reload", key: "r", modifiers: .command) {
            $0.reload()
        },
        LotusShortcut("reloadFromOrigin", key: "r", modifiers: [.command, .shift], usesEventMonitor: true) {
            $0.reloadFromOrigin()
        },
        LotusShortcut("viewSource", key: "u", modifiers: [.command, .option], usesEventMonitor: true) {
            $0.viewPageSource()
        },
        LotusShortcut("inspectElement", key: "i", modifiers: [.command, .option], usesEventMonitor: true) {
            $0.inspectElement()
        },
        LotusShortcut("toggleZapMode", key: "z", modifiers: [.command, .option], usesEventMonitor: true) {
            $0.toggleZapMode()
        },
        LotusShortcut("back", key: "[", modifiers: .command) {
            $0.goBack()
        },
        LotusShortcut("forward", key: "]", modifiers: .command) {
            $0.goForward()
        },
        LotusShortcut("printPage", key: "p", modifiers: .command, usesEventMonitor: true) {
            $0.printPage()
        },
        // Arrow-key navigation must go through the NSEvent monitor: SwiftUI
        // keyboard shortcuts are unreliable while WKWebView is first responder.
        LotusShortcut("backArrow", key: .leftArrow, modifiers: .command,
                      guardsTextInput: true, usesEventMonitor: true) {
            $0.goBack()
        },
        LotusShortcut("forwardArrow", key: .rightArrow, modifiers: .command,
                      guardsTextInput: true, usesEventMonitor: true) {
            $0.goForward()
        },

        // MARK: Zoom
        LotusShortcut("zoomInPlus", key: "=", modifiers: [.command, .shift], usesEventMonitor: true) {
            $0.zoomIn()
        },
        LotusShortcut("zoomInEquals", key: "=", modifiers: .command, usesEventMonitor: true) {
            $0.zoomIn()
        },
        LotusShortcut("zoomOut", key: "-", modifiers: .command, usesEventMonitor: true) {
            $0.zoomOut()
        },
        LotusShortcut("zoomActualSize", key: "0", modifiers: .command, usesEventMonitor: true) {
            $0.resetZoom()
        },

        // MARK: Tab Selection
        LotusShortcut("nextTabControlTab", key: .tab, modifiers: .control, action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("nextTabBracket", key: "]", modifiers: [.command, .shift], action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("nextTabArrow", key: .rightArrow, modifiers: [.command, .option], action: animated {
            $0.selectNextTab()
        }),
        LotusShortcut("previousTabControlTab", key: .tab, modifiers: [.control, .shift], action: animated {
            $0.selectPreviousTab()
        }),
        LotusShortcut("previousTabBracket", key: "[", modifiers: [.command, .shift], action: animated {
            $0.selectPreviousTab()
        }),
        LotusShortcut("previousTabArrow", key: .leftArrow, modifiers: [.command, .option], action: animated {
            $0.selectPreviousTab()
        }),

        // MARK: Profiles
        LotusShortcut("nextProfile", key: .rightArrow, modifiers: [.control, .option], usesEventMonitor: true) {
            $0.switchToNextProfile()
        },
        LotusShortcut("previousProfile", key: .leftArrow, modifiers: [.control, .option], usesEventMonitor: true) {
            $0.switchToPreviousProfile()
        },
    ] + (1...9).map { index in
        LotusShortcut("selectTab\(index)", key: KeyEquivalent(Character("\(index)")), modifiers: .command, action: animated {
            $0.selectTabAtIndex(index - 1)
        })
    }

    /// Shortcuts that live outside this table because they need view-local
    /// state. Listed here so conflicts remain visible in one place.
    ///
    /// | Shortcut | Location                        | Why it's local             |
    /// |----------|---------------------------------|----------------------------|
    /// | ⌘Q       | Menu bar (`LotusApp.commands`)  | Standard menu-item route   |
    /// | Esc/↩    | `QuitConfirmationView` buttons  | Sheet-local default/cancel |
    static let localExceptions: [String] = [
        "⌘Q — Quit (menu bar CommandGroup → requestQuit)",
        "Esc / ↩ — Quit confirmation sheet buttons",
        "Esc / ↩ / ↑↓⇥ — CommandPalette field (view-local suggestion navigation)",
        "Esc / ↩ / ⇧↩ — FindBarView field (find dismissal and match navigation)",
    ]

    /// All entries routed through the NSEvent key-down monitor.
    static var eventMonitorEntries: [LotusShortcut] {
        table.filter { $0.usesEventMonitor }
    }

    /// Surfaces conflicting registrations (same key + modifiers appearing
    /// more than once). Intentionally allows exact duplicates created by
    /// multiple bindings for one logical action only when ids differ but
    /// actions differ — those are real conflicts worth flagging in debug.
    static func debugAssertNoConflicts() {
        var seen: [String: String] = [:]
        for shortcut in table {
            let combo = "\(shortcut.modifiers.rawValue)-\(shortcut.key)"
            if let existingID = seen[combo], existingID != shortcut.id {
                assertionFailure(
                    "Keyboard shortcut conflict: \(shortcut.displayString) is bound to both '\(existingID)' and '\(shortcut.id)'"
                )
            } else {
                seen[combo] = shortcut.id
            }
        }
    }
}

// MARK: - Event Monitor Routing

enum KeyboardShortcutRouter {

    private static let keyCodeToKey: [UInt16: KeyEquivalent] = [
        123: .leftArrow,
        124: .rightArrow,
        125: .downArrow,
        126: .upArrow,
        48: .tab,
        36: .return,
        76: .return,
        53: .escape,
        51: .delete,
    ]

    static func keyEquivalent(for event: NSEvent) -> KeyEquivalent? {
        if let special = keyCodeToKey[event.keyCode] {
            return special
        }
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let firstChar = chars.first else {
            return nil
        }
        return KeyEquivalent(firstChar)
    }

    /// Matches a key-down event against modal sheets and the global shortcut table.
    /// Returns nil if the event was consumed.
    static func handleKeyEvent(_ event: NSEvent, browserState: BrowserState) -> NSEvent? {
        guard event.type == .keyDown else { return event }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // 1. Quit confirmation modal keyboard handling (Enter / Esc / ⌘Q)
        if browserState.isQuitConfirmationPresented {
            if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                DispatchQueue.main.async {
                    browserState.confirmQuit(alwaysQuit: false)
                }
                return nil
            }
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.cancelQuit()
                }
                return nil
            }
            if flags.contains(.command),
               let chars = event.charactersIgnoringModifiers?.lowercased(),
               chars == "q" {
                DispatchQueue.main.async {
                    browserState.confirmQuit(alwaysQuit: false)
                }
                return nil
            }
            return nil
        }

        // 2. Folder close confirmation modal keyboard handling (Enter / Esc)
        if let folderId = browserState.folderToCloseConfirmation {
            if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                DispatchQueue.main.async {
                    browserState.confirmCloseFolder(id: folderId, keepTabs: false)
                }
                return nil
            }
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.cancelCloseFolder()
                }
                return nil
            }
            return nil
        }

        // 3. Delete profile confirmation modal keyboard handling (Enter / Esc)
        if browserState.profileToDeleteConfirmation != nil {
            if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                DispatchQueue.main.async {
                    browserState.confirmDeleteProfile()
                }
                return nil
            }
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.cancelDeleteProfile()
                }
                return nil
            }
            return nil
        }

        // Profile editing/creation modal keyboard handling (Esc)
        if browserState.profileToEdit != nil {
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.closeProfileEditor()
                }
                return nil
            }
        }
        if browserState.isCreatingProfile {
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.closeCreateProfile()
                }
                return nil
            }
        }

        // 5. Clear all data confirmation modal keyboard handling (Enter / Esc)
        if browserState.isClearAllDataConfirmationPresented {
            if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
                DispatchQueue.main.async {
                    browserState.clearAllBrowserData {
                        browserState.isClearAllDataConfirmationPresented = false
                    }
                }
                return nil
            }
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async {
                    browserState.isClearAllDataConfirmationPresented = false
                }
                return nil
            }
            return nil
        }

        // 6. Find on Page dismiss on Escape
        if browserState.isFindPresented && event.keyCode == 53 { // Escape
            DispatchQueue.main.async {
                browserState.closeFind()
            }
            return nil
        }

        // 2. Match against global shortcut table
        guard let key = keyEquivalent(for: event) else { return event }
        let modifiers = EventModifiers(flags)

        let match = LotusShortcuts.table.first { shortcut in
            shortcut.effectiveKey == key && shortcut.effectiveModifiers == modifiers
        }

        guard let match = match else { return event }
        if match.guardsTextInput && browserState.isAnyTextInputFocused {
            return event
        }

        DispatchQueue.main.async {
            match.action(browserState)
        }
        // Consume the event so it does not pass to the WKWebView or cause duplicates.
        return nil
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var modifiers: EventModifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self = modifiers
    }
}

// MARK: - SwiftUI Rendering

/// Renders shortcut table entries as invisible buttons for standard SwiftUI accessibility.
struct GlobalShortcutHandlers: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject private var shortcutManager = ShortcutManager.shared

    var body: some View {
        ForEach(LotusShortcuts.table.filter { !$0.usesEventMonitor }) { shortcut in
            Button("") {
                shortcut.action(browserState)
            }
            .keyboardShortcut(shortcut.effectiveKey, modifiers: shortcut.effectiveModifiers)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
    }
}

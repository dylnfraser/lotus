//
//  LotusApp.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

@main
struct LotusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some Scene {
        // The id lets views open additional windows programmatically via
        // `openWindow(id: "main")` (toolbar ellipsis menu → New Window).
        WindowGroup(id: "main") {
            ContentView()
                .preferredColorScheme(preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands {
            LotusMenuCommands()
        }

        WindowGroup(id: "private") {
            ContentView(isPrivate: true)
                .preferredColorScheme(preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}

extension Notification.Name {
    static let lotusOpenNewWindow = Notification.Name("lotus.browser.openNewWindow")
    static let lotusOpenNewPrivateWindow = Notification.Name("lotus.browser.openNewPrivateWindow")
}

// MARK: - App Menu Commands

private struct LotusMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // MARK: Lotus (App)
        CommandGroup(replacing: .appInfo) {
            Button("About Lotus") {
                AppDelegate.sharedBrowserState?.openSettingsPage()
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                AppDelegate.sharedBrowserState?.openSettingsPage()
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Lotus") {
                if let browserState = AppDelegate.sharedBrowserState {
                    browserState.requestQuit()
                } else {
                    NSApp.terminate(nil)
                }
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        // MARK: File
        CommandGroup(replacing: .newItem) {
            Button("New Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Private Window") {
                openWindow(id: "private")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Tab") {
                AppDelegate.sharedBrowserState?.toggleCommandPalette()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Open Location…") {
                AppDelegate.sharedBrowserState?.openCommandPaletteForCurrentTab()
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Open File…") {
                AppDelegate.sharedBrowserState?.openFilePrompt()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Close Tab") {
                if let state = AppDelegate.sharedBrowserState {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        state.removeTab(id: state.selectedTabId)
                    }
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Archive Tab") {
                if let state = AppDelegate.sharedBrowserState {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        state.archiveTab(id: state.selectedTabId)
                    }
                }
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Close Window") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save Page As…") {
                AppDelegate.sharedBrowserState?.savePageAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                AppDelegate.sharedBrowserState?.printPage()
            }
            .keyboardShortcut("p", modifiers: .command)
        }

        // MARK: Edit
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: .command)

            Button("Copy") {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: .command)

            Button("Copy Page Address") {
                AppDelegate.sharedBrowserState?.copyCurrentPageURL()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Paste") {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: .command)

            Button("Paste and Match Style") {
                NSApp.sendAction(Selector(("pasteAsPlainText:")), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .option, .shift])

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: .command)

            Divider()

            Button("Find in Page…") {
                AppDelegate.sharedBrowserState?.toggleFind()
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find Next") {
                AppDelegate.sharedBrowserState?.findNext()
            }
            .keyboardShortcut("g", modifiers: .command)

            Button("Find Previous") {
                AppDelegate.sharedBrowserState?.findPrevious()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        }

        // MARK: View
        CommandGroup(replacing: .toolbar) {
            Button("Actual Size") {
                AppDelegate.sharedBrowserState?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Zoom In") {
                AppDelegate.sharedBrowserState?.zoomIn()
            }
            .keyboardShortcut("=", modifiers: .command)

            Button("Zoom Out") {
                AppDelegate.sharedBrowserState?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)

            Divider()

            Button("Reload Page") {
                AppDelegate.sharedBrowserState?.reload()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Force Reload Page") {
                AppDelegate.sharedBrowserState?.reloadFromOrigin()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Divider()

            Button("Toggle Sidebar") {
                AppDelegate.sharedBrowserState?.toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("Downloads") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "Downloads", url: .lotusDownloads)
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Button("Website Data") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "Website Data", url: .lotusWebsiteData)
            }

            Button("Keyboard Shortcuts") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "Shortcuts", url: .lotusShortcuts)
            }

            Divider()

            Button("Toggle Full Screen") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])
        }

        // MARK: History
        CommandMenu("History") {
            Button("Back") {
                AppDelegate.sharedBrowserState?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Forward") {
                AppDelegate.sharedBrowserState?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)

            Divider()

            Button("Reopen Closed Tab") {
                AppDelegate.sharedBrowserState?.reopenLastClosedTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("Show All History") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "History", url: .lotusHistory)
            }
            .keyboardShortcut("y", modifiers: .command)

            Button("Clear History…") {
                AppDelegate.sharedBrowserState?.clearHistory()
            }

            if let entries = AppDelegate.sharedBrowserState?.historyEntries, !entries.isEmpty {
                Divider()
                ForEach(Array(entries.prefix(10))) { entry in
                    Button {
                        AppDelegate.sharedBrowserState?.loadURL(entry.url)
                    } label: {
                        Text(entry.title.isEmpty ? (entry.displayHost ?? entry.url.absoluteString) : entry.title)
                    }
                }
            }
        }

        // MARK: Bookmarks
        CommandMenu("Bookmarks") {
            Button("Add Bookmark…") {
                AppDelegate.sharedBrowserState?.toggleBookmark()
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("Show All Bookmarks") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "Bookmarks", url: .lotusBookmarks)
            }
            .keyboardShortcut("b", modifiers: [.command, .option])

            if let bookmarks = AppDelegate.sharedBrowserState?.bookmarks, !bookmarks.isEmpty {
                Divider()
                ForEach(Array(bookmarks.prefix(15))) { item in
                    Button {
                        AppDelegate.sharedBrowserState?.openTab(at: item.url, title: item.title)
                    } label: {
                        Text(item.title.isEmpty ? item.displayDomain : item.title)
                    }
                }
            }
        }

        // MARK: Profiles
        CommandMenu("Profiles") {
            if let state = AppDelegate.sharedBrowserState {
                ForEach(state.profiles) { p in
                    Button {
                        state.switchProfile(to: p.id)
                    } label: {
                        HStack {
                            Text(p.name)
                            if p.id == state.currentProfileId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Divider()

                Button("Next Profile") {
                    state.switchToNextProfile()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.control, .option])

                Button("Previous Profile") {
                    state.switchToPreviousProfile()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.control, .option])

                Divider()

                Button("Manage Profiles…") {
                    state.openSettingsPage()
                }
            }
        }

        // MARK: Develop
        CommandMenu("Develop") {
            Button("Reload Page") {
                AppDelegate.sharedBrowserState?.reload()
            }

            Button("Force Reload Page") {
                AppDelegate.sharedBrowserState?.reloadFromOrigin()
            }

            Divider()

            Button("View Page Source") {
                AppDelegate.sharedBrowserState?.viewPageSource()
            }
            .keyboardShortcut("u", modifiers: [.command, .option])

            Button("Inspect Element") {
                AppDelegate.sharedBrowserState?.inspectElement()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        // MARK: Window
        CommandGroup(replacing: .windowSize) {
            Button("Minimize") {
                NSApp.keyWindow?.miniaturize(nil)
            }
            .keyboardShortcut("m", modifiers: .command)

            Button("Zoom") {
                NSApp.keyWindow?.zoom(nil)
            }
        }

        CommandGroup(replacing: .windowArrangement) {
            Button("Bring All to Front") {
                NSApp.arrangeInFront(nil)
            }
        }

        // MARK: Help
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") {
                AppDelegate.sharedBrowserState?.addTabBelow(title: "Shortcuts", url: .lotusShortcuts)
            }

            Divider()

            Button("Lotus Help") {
                if let url = URL(string: "https://github.com/dylanfraser/Lotus") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

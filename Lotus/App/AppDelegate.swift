//
//  AppDelegate.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var sharedBrowserState: BrowserState?
    static var isForcedTermination: Bool = false

    private static var pendingMainURLs: [URL] = []
    private static var pendingPrivateURLs: [URL] = []
    private static let pendingURLQueue = DispatchQueue(label: "lotus.pendingURLs")

    static func enqueuePendingURL(_ url: URL, isPrivate: Bool) {
        pendingURLQueue.sync {
            if isPrivate {
                pendingPrivateURLs.append(url)
            } else {
                pendingMainURLs.append(url)
            }
        }
    }

    static func dequeuePendingURL(isPrivate: Bool) -> URL? {
        pendingURLQueue.sync {
            if isPrivate {
                return pendingPrivateURLs.isEmpty ? nil : pendingPrivateURLs.removeFirst()
            } else {
                return pendingMainURLs.isEmpty ? nil : pendingMainURLs.removeFirst()
            }
        }
    }

    override init() {
        super.init()
        NSWindow.allowsAutomaticWindowTabbing = false
        NSResponder.suppressUnhandledKeyBeep()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.isFileURL {
                Self.sharedBrowserState?.openTab(at: url, title: url.lastPathComponent)
            } else if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" || scheme == "lotus" {
                Self.sharedBrowserState?.openTab(at: url, title: url.host ?? "New Tab")
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        Self.sharedBrowserState?.openTab(at: url, title: url.lastPathComponent)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    static func forceTerminate() {
        isForcedTermination = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.isForcedTermination || UserDefaults.standard.bool(forKey: BrowserState.alwaysQuitKey) {
            return .terminateNow
        }

        if let browserState = Self.sharedBrowserState {
            DispatchQueue.main.async {
                browserState.requestQuit()
            }
            return .terminateCancel
        }

        return .terminateNow
    }
}

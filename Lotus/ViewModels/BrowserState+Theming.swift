//
//  BrowserState+Theming.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import WebKit

extension BrowserState {

    func themeColor(for tabId: UUID) -> Color? {
        themeColors[tabId]?.color
    }

    func isThemeLight(for tabId: UUID) -> Bool {
        themeColors[tabId]?.isLight ?? false
    }

    /// Resolves the tab's dynamic site theme color (meta theme-color, active DOM background, or extracted favicon color).
    func effectiveTabTheme(for tabId: UUID) -> (color: Color, isLight: Bool)? {
        guard let tab = tab(for: tabId), tab.url?.isLotusPage != true else { return nil }

        if let host = tab.url?.host?.lowercased(), host.contains("apple.com") {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return (isDark ? .white : .black, !isDark)
        }

        if let theme = themeColors[tabId] {
            return (theme.color, theme.isLight)
        }

        if tabId == selectedTabId, let active = activeThemeColor {
            return (active, isThemeLight)
        }

        if let favURL = tab.faviconURL,
           let nsColor = FaviconColorExtractor.shared.nsColor(for: favURL) {
            let isLight = ColorParser.isLight(color: nsColor)
            return (Color(nsColor: nsColor), isLight)
        }

        return nil
    }

    /// Computes the effective background color and text contrast for any tab based on tinting mode,
    /// site theme/favicon color, profile space color, and dark/light appearance.
    func effectiveTabColor(for tab: TabItem, colorScheme: ColorScheme) -> (color: Color, isLight: Bool) {
        let isInternal = tab.url?.isLotusPage == true
        if isInternal {
            return (Color(nsColor: .windowBackgroundColor), colorScheme == .light)
        }

        let profile = self.profile(for: tab.profileId ?? self.currentProfileId) ?? self.currentProfile
        let mode = UserDefaults.standard.string(forKey: "lotus.browser.sidebarTabTintingMode") ?? "adaptive"

        let profileColor = profile.color == .grey ? Color(nsColor: .windowBackgroundColor) : profile.color.color
        let isProfileLight = (LotusAccentColor(rawValue: profile.color.accentColorEquivalent.rawValue) ?? .white) == .yellow

        switch mode {
        case "neutral":
            return (Color(nsColor: .windowBackgroundColor), colorScheme == .light)
        case "systemAccent":
            let isLight = profile.color == .grey ? (colorScheme == .light) : isProfileLight
            return (profileColor, isLight)
        default: // "adaptive"
            if let siteTheme = effectiveTabTheme(for: tab.id) {
                return (siteTheme.color, siteTheme.isLight)
            }
            let isLight = profile.color == .grey ? (colorScheme == .light) : isProfileLight
            return (profileColor, isLight)
        }
    }

    func updateThemeColor(for tabId: UUID, parsed: ParsedThemeColor) {
        // Late-arriving extractions (e.g. from a page being navigated away
        // from) must not tint a tab that is now on an internal page.
        guard tab(for: tabId)?.url?.isLotusPage != true else { return }
        themeColors[tabId] = parsed
        themeBloomTrigger[tabId, default: 0] += 1
        if selectedTabId == tabId {
            withAnimation(.easeInOut(duration: 0.22)) {
                self.activeThemeColor = parsed.color
                self.activeThemeNSColor = parsed.nsColor
                self.isThemeLight = parsed.isLight
            }
        }
    }

    func detectedAccentNSColor(for tabId: UUID) -> NSColor {
        let tabURL = url(for: tabId)
        if let host = tabURL?.host?.lowercased(), host.contains("apple.com") {
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? .white : .black
        }
        if let faviconURL = tab(for: tabId)?.faviconURL,
           let extracted = FaviconColorExtractor.shared.nsColor(for: faviconURL) {
            return extracted
        }
        if let theme = themeColors[tabId]?.nsColor {
            return theme
        }
        if let active = activeThemeNSColor {
            return active
        }
        return NSColor.controlAccentColor
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        extractThemeColor(from: webView)
        extractFavicon(from: webView)
        if let tabId = webViewStore.first(where: { $0.value === webView })?.key {
            applyZapRules(for: tabId)
            if wakingTabIds.contains(tabId) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        self.wakingTabIds.remove(tabId)
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        extractThemeColor(from: webView)
        extractFavicon(from: webView)
        if let tabId = webViewStore.first(where: { $0.value === webView })?.key {
            applyZapRules(for: tabId)
            if wakingTabIds.contains(tabId) {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        self.wakingTabIds.remove(tabId)
                    }
                }
            }
            // Capture updated snapshot once DOM is fully rendered and idle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, let wv = self.webViewStore[tabId] else { return }
                TabSnapshotStore.shared.captureSnapshot(for: tabId, webView: wv)
            }
        }
    }

    func extractThemeColor(from webView: WKWebView) {
        guard let tabId = webViewStore.first(where: { $0.value === webView })?.key else { return }
        // Internal pages are blank scheme-handler documents; never let them
        // tint the chrome.
        guard webView.url?.isLotusPage != true else { return }

        webView.evaluateJavaScript(UserScripts.themeColorProbe) { [weak self] result, _ in
            guard let self = self, let colorString = result as? String else { return }
            if let parsed = ColorParser.parse(colorString) {
                DispatchQueue.main.async {
                    self.updateThemeColor(for: tabId, parsed: parsed)
                }
            }
        }
    }

    func extractFavicon(from webView: WKWebView) {
        guard let tabId = webViewStore.first(where: { $0.value === webView })?.key else { return }
        guard webView.url?.isLotusPage != true else { return }

        webView.evaluateJavaScript(UserScripts.faviconProbe) { [weak self] result, _ in
            guard let self = self,
                  let urlString = result as? String,
                  let favURL = URL(string: urlString) else { return }
            DispatchQueue.main.async {
                if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    if self.tabs[index].customFaviconURL != favURL {
                        self.tabs[index].customFaviconURL = favURL
                        FaviconColorExtractor.shared.prefetch(for: favURL)
                    }
                }
            }
        }
    }
}

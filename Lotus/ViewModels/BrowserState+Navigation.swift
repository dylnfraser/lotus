//
//  BrowserState+Navigation.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI
import AppKit
import WebKit

extension BrowserState {

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased()
        let allowedSchemes: Set<String> = [
            "http", "https", "about", "lotus", "blob", "data", "javascript",
            "webkit-extension", "chrome-extension"
        ]

        // Never delegate local file URLs originating in web content to Finder
        // or another application. A page must not be able to launch local apps
        // or open arbitrary local paths through navigation.
        if scheme == "file" {
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
            }
            return
        }

        // Disallow third-party web content from navigating to privileged internal lotus:// schemes.
        if scheme == "lotus" {
            let isLink = navigationAction.navigationType == .linkActivated
            let sourceProtocol = navigationAction.sourceFrame.securityOrigin.protocol.lowercased()
            let hasWebSourceOrigin = sourceProtocol == "http" || sourceProtocol == "https"
            let isCurrentURLWeb = webView.url.map { !$0.isLotusPage } ?? false

            if isLink && isCurrentURLWeb {
                decisionHandler(.cancel)
                return
            }
            if hasWebSourceOrigin {
                decisionHandler(.cancel)
                return
            }
        }

        // External protocols (for example, mailto:, tel:, slack:, zoommtg:) require
        // user confirmation before Lotus asks macOS to open the handler app.
        if let scheme, !allowedSchemes.contains(scheme) {
            decisionHandler(.cancel)
            DispatchQueue.main.async { [weak self] in
                self?.presentExternalURLConfirmation(for: url, from: webView)
            }
            return
        }

        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        let isCmdPressed = navigationAction.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)
        let isLinkClick = navigationAction.navigationType == .linkActivated

        // Strict popup & link shield: blocks link clicks and new window navigations for the page
        let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
        let currentSourceURL = webView.url ?? tab(for: sourceTabId)?.url
        if ContentBlockerService.shared.isStrictPopupBlockingActive(for: currentSourceURL) {
            if navigationAction.targetFrame == nil || isLinkClick {
                decisionHandler(.cancel)
                return
            }
        }

        // HTTPS-Only Mode upgrade
        if ContentBlockerService.shared.httpsOnlyModeEnabled && scheme == "http" {
            let host = url.host?.lowercased() ?? ""
            let isLocal = host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local") || host.isEmpty
            if !isLocal && !httpAllowedDomains.contains(host) && navigationAction.targetFrame?.isMainFrame != false {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                components?.scheme = "https"
                if let upgradedURL = components?.url {
                    decisionHandler(.cancel)
                    DispatchQueue.main.async { [weak self] in
                        self?.loadURL(upgradedURL, in: sourceTabId)
                    }
                    return
                }
            }
        }

        if isCmdPressed && isLinkClick && scheme != "about" {
            DispatchQueue.main.async { [weak self] in
                self?.openTabFromCmdClick(sourceTabId: sourceTabId, title: url.host ?? "New Tab", url: url, select: false)
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    private func presentExternalURLConfirmation(for url: URL, from webView: WKWebView) {
        let appName = NSWorkspace.shared.urlForApplication(toOpen: url)?.deletingPathExtension().lastPathComponent
        let targetDescription = appName.map { "“\($0)”" } ?? "an external application"
        
        let alert = NSAlert()
        alert.messageText = "Open in \(targetDescription)?"
        alert.informativeText = "This page is requesting to open \(url.absoluteString) outside Lotus."
        alert.addButton(withTitle: "Open")
        alert.addButton(withTitle: "Cancel")

        if let window = webView.window ?? NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                guard response == .alertFirstButtonReturn else { return }
                NSWorkspace.shared.open(url)
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        if let httpResponse = navigationResponse.response as? HTTPURLResponse,
           let disposition = (httpResponse.allHeaderFields["Content-Disposition"] ?? httpResponse.allHeaderFields["content-disposition"]) as? String,
           disposition.lowercased().contains("attachment") {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        handleDownloadInitiated(download, from: navigationAction.request.url)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        handleDownloadInitiated(download, from: navigationResponse.response.url)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let sourceTabId = webViewStore.first(where: { $0.value === webView })?.key ?? selectedTabId
        let sourceURL = webView.url ?? tab(for: sourceTabId)?.url

        // If strict popup & link blocking is active on this page, silently block all popup window attempts
        if ContentBlockerService.shared.isStrictPopupBlockingActive(for: sourceURL) {
            return nil
        }

        let targetURL = navigationAction.request.url
        let isCmdPressed = navigationAction.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.command)

        if isPrivate {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        WebViewFactory.configurePopup(configuration)
        let tabTitle = targetURL?.host ?? "New Tab"
        let newTab = isCmdPressed
            ? openTabFromCmdClick(sourceTabId: sourceTabId, title: tabTitle, url: targetURL, select: true)
            : addTabBelow(currentTabId: sourceTabId, title: tabTitle, url: targetURL, select: true)

        let newWebView = WebViewFactory.makeWebView(configuration: configuration, delegate: self)
        webViewStore[newTab.id] = newWebView
        setupObservers(for: newTab.id, webView: newWebView)

        return newWebView
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust,
           let tabId = webViewStore.first(where: { $0.value === webView })?.key {
            self.tabServerTrusts[tabId] = trust
        }
        // Let WebKit and the system trust store validate server certificates.
        completionHandler(.performDefaultHandling, nil)
    }

    func certificateDetails(for tabId: UUID) -> CertificateDetails? {
        guard let url = url(for: tabId), let host = url.host else { return nil }
        guard let trust = tabServerTrusts[tabId] else { return nil }
        return CertificateDetails.from(trust: trust, host: host)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let tabId = self.webViewStore.first(where: { $0.value === webView })?.key {
                self.pageLoadErrors[tabId] = nil
                if self.isZapModeActive && self.selectedTabId == tabId {
                    self.stopZapMode(for: tabId)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let tabId = self.webViewStore.first(where: { $0.value === webView })?.key {
                self.tabLoadingStates[tabId] = false
                if self.selectedTabId == tabId {
                    self.isLoading = false
                }

                let failingURL = webView.url ?? self.tab(for: tabId)?.url
                let isHTTPSFailure = ContentBlockerService.shared.httpsOnlyModeEnabled && failingURL?.scheme == "https"
                let pageError = PageLoadError(url: failingURL, error: error, isHTTPSEnforcedFailure: isHTTPSFailure)
                self.pageLoadErrors[tabId] = pageError
                if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    self.tabs[index].title = pageError.title
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let tabId = self.webViewStore.first(where: { $0.value === webView })?.key {
                self.tabLoadingStates[tabId] = false
                if self.selectedTabId == tabId {
                    self.isLoading = false
                }

                let failingURL = webView.url ?? self.tab(for: tabId)?.url
                let isHTTPSFailure = ContentBlockerService.shared.httpsOnlyModeEnabled && failingURL?.scheme == "https"
                let pageError = PageLoadError(url: failingURL, error: error, isHTTPSEnforcedFailure: isHTTPSFailure)
                self.pageLoadErrors[tabId] = pageError
                if let index = self.tabs.firstIndex(where: { $0.id == tabId }) {
                    self.tabs[index].title = pageError.title
                }
            }
        }
    }

    // MARK: - Navigation State Accessors

    func canGoBack(for tabId: UUID) -> Bool {
        webViewStore[tabId]?.canGoBack ?? false
    }

    func canGoForward(for tabId: UUID) -> Bool {
        webViewStore[tabId]?.canGoForward ?? false
    }

    func isLoading(for tabId: UUID) -> Bool {
        tabLoadingStates[tabId] ?? webViewStore[tabId]?.isLoading ?? false
    }

    func estimatedProgress(for tabId: UUID) -> Double {
        tabEstimatedProgress[tabId] ?? webViewStore[tabId]?.estimatedProgress ?? 0.0
    }

    // MARK: - Navigation Actions

    func goBack(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        if wv.canGoBack {
            wv.goBack()
        }
    }

    func goForward(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        if wv.canGoForward {
            wv.goForward()
        }
    }

    func reload(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        pageLoadErrors[targetId] = nil
        if let index = tabs.firstIndex(where: { $0.id == targetId }), let url = tabs[index].url {
            tabs[index].title = URLInputResolver.initialTitle(for: url, input: url.absoluteString)
        }
        let wv = getWebView(for: targetId)
        if wv.url != nil {
            wv.reload()
        } else if let targetURL = tab(for: targetId)?.url {
            if targetURL.isFileURL {
                wv.loadFileURL(targetURL, allowingReadAccessTo: targetURL.deletingLastPathComponent())
            } else {
                wv.load(URLRequest(url: targetURL))
            }
        }
    }

    func reloadFromOrigin(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        pageLoadErrors[targetId] = nil
        if let index = tabs.firstIndex(where: { $0.id == targetId }), let url = tabs[index].url {
            tabs[index].title = URLInputResolver.initialTitle(for: url, input: url.absoluteString)
        }
        let wv = getWebView(for: targetId)
        if wv.url != nil {
            wv.reloadFromOrigin()
        } else if let targetURL = tab(for: targetId)?.url {
            if targetURL.isFileURL {
                wv.loadFileURL(targetURL, allowingReadAccessTo: targetURL.deletingLastPathComponent())
            } else {
                wv.load(URLRequest(url: targetURL))
            }
        }
    }

    func allowInsecureHTTPLoad(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let error = pageLoadErrors[targetId], let failedURL = error.url, let host = failedURL.host else { return }
        httpAllowedDomains.insert(host.lowercased())
        pageLoadErrors[targetId] = nil
        var components = URLComponents(url: failedURL, resolvingAgainstBaseURL: true)
        components?.scheme = "http"
        if let httpURL = components?.url {
            loadURL(httpURL, in: targetId)
        }
    }

    func backHistoryList(for tabId: UUID) -> [WKBackForwardListItem] {
        guard let wv = webViewStore[tabId] else { return [] }
        return Array(wv.backForwardList.backList.reversed())
    }

    func forwardHistoryList(for tabId: UUID) -> [WKBackForwardListItem] {
        guard let wv = webViewStore[tabId] else { return [] }
        return wv.backForwardList.forwardList
    }

    func goToBackForwardItem(_ item: WKBackForwardListItem, for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let wv = webViewStore[targetId] else { return }
        pageLoadErrors[targetId] = nil
        wv.go(to: item)
    }

    func viewPageSource(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let currentURL = url(for: targetId), !currentURL.isLotusPage else { return }
        let wv = getWebView(for: targetId)
        wv.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let rawHTML = (result as? String) ?? ""
                let escapedHTML = rawHTML
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")

                let styledDoc = """
                <!DOCTYPE html>
                <html>
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Source: \(currentURL.host ?? "Page")</title>
                <style>
                body { margin: 0; padding: 16px 20px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 13px; line-height: 1.5; background: #18181A; color: #E4E4E7; tab-size: 4; }
                @media (prefers-color-scheme: light) { body { background: #FFFFFF; color: #18181B; } }
                pre { margin: 0; white-space: pre-wrap; word-break: break-all; }
                </style>
                </head>
                <body>
                <pre><code>\(escapedHTML)</code></pre>
                </body>
                </html>
                """

                let newTab = self.addTabBelow(
                    currentTabId: targetId,
                    title: "Source: \(currentURL.host ?? "Page")",
                    url: URL(string: "about:blank"),
                    select: true
                )
                let newWV = self.getWebView(for: newTab.id)
                newWV.loadHTMLString(styledDoc, baseURL: currentURL)
            }
        }
    }

    func inspectElement(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        guard let wv = webViewStore[targetId] else { return }
        if wv.responds(to: NSSelectorFromString("_showInspector")) {
            wv.perform(NSSelectorFromString("_showInspector"))
        }
    }

    func stopLoading(for tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        let wv = getWebView(for: targetId)
        wv.stopLoading()
        tabLoadingStates[targetId] = false
        if selectedTabId == targetId {
            isLoading = false
        }
    }

    func navigateTab(id: UUID, to input: String) {
        guard let url = URLInputResolver.resolve(input) else { return }
        pageLoadErrors[id] = nil
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].url = url
            tabs[index].title = URLInputResolver.initialTitle(for: url, input: input)
        }

        // lotus:// URLs load through LotusSchemeHandler so internal pages
        // join the back-forward list like any other navigation.
        let wv = getWebView(for: id)
        wv.load(URLRequest(url: url))
    }

    /// Loads an already-resolved URL in a tab's webview (used by internal
    /// pages like history to replace their own page in-place).
    func loadURL(_ url: URL, in tabId: UUID? = nil) {
        let targetId = tabId ?? selectedTabId
        pageLoadErrors[targetId] = nil
        if let index = tabs.firstIndex(where: { $0.id == targetId }) {
            tabs[index].url = url
            tabs[index].title = url.isFileURL ? url.lastPathComponent : (url.lotusPageTitle ?? url.host ?? url.absoluteString)
        }

        let wv = getWebView(for: targetId)
        if url.isFileURL {
            wv.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            wv.load(URLRequest(url: url))
        }
    }

    func navigateActiveTab(to input: String) {
        navigateTab(id: selectedTabId, to: input)
    }

    /// Opens a tab triggered by ⌘-click, grouping it into a tab group/folder with the source tab.
    @discardableResult
    func openTabFromCmdClick(sourceTabId: UUID, title: String = "New Tab", url: URL?, select: Bool = false) -> TabItem {
        guard let sourceTab = tab(for: sourceTabId) else {
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        let autoGroup = (UserDefaults.standard.object(forKey: "lotus.browser.autoGroupTabs") as? Bool) ?? true
        if !autoGroup {
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        // If the source tab is already in a folder, add the new tab to the existing folder
        if let folderId = sourceTab.folderId {
            expandFolder(id: folderId)
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        // Pinned tabs cannot belong to folders. Keep the source pinned and
        // open its child as a regular unpinned tab instead of grouping them.
        if sourceTab.isPinned {
            return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
        }

        // If the source tab is not in a folder, create a new tab group with it
        let groupName: String
        let trimmedTitle = sourceTab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty && trimmedTitle != "New Tab" && trimmedTitle != "Lotus" {
            groupName = trimmedTitle
        } else if let host = sourceTab.url?.host, !host.isEmpty {
            groupName = host
        } else {
            groupName = "Tab Group"
        }

        let folder = createFolder(named: groupName, with: sourceTabId)
        expandFolder(id: folder.id)
        return addTabBelow(currentTabId: sourceTabId, title: title, url: url, select: select)
    }

    func updateNavigationState() {
        // With the palette-based new-tab flow the tabs list can be empty;
        // never conjure a webview for an id that has no tab behind it.
        guard tab(for: selectedTabId) != nil else {
            self.canGoBack = false
            self.canGoForward = false
            self.isLoading = false
            self.estimatedProgress = 0.0
            self.activeThemeColor = nil
            self.activeThemeNSColor = nil
            self.isThemeLight = false
            return
        }
        let wv = getWebView(for: selectedTabId)
        self.canGoBack = wv.canGoBack
        self.canGoForward = wv.canGoForward
        self.tabLoadingStates[selectedTabId] = wv.isLoading
        self.tabEstimatedProgress[selectedTabId] = wv.estimatedProgress
        self.isLoading = wv.isLoading
        self.estimatedProgress = wv.estimatedProgress
        // Internal pages always present with the system appearance, even if
        // the tab still caches the previous site's theme for Back.
        let parsed = activeURL?.isLotusPage == true ? nil : self.themeColors[selectedTabId]
        self.activeThemeColor = parsed?.color
        self.activeThemeNSColor = parsed?.nsColor
        self.isThemeLight = parsed?.isLight ?? false
    }
}

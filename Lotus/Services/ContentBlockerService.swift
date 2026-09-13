//
//  ContentBlockerService.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import Foundation
import WebKit
import Combine

/// Central service managing WebKit content blocking rules, compilation,
/// allowlists, and per-site shield states.
final class ContentBlockerService: ObservableObject {

    static let shared = ContentBlockerService()

    private static let userDefaultsKey = "lotus.browser.contentBlocker.settings"

    private var isRestoringSettings = false

    @Published var isAdBlockingEnabled: Bool = true {
        didSet {
            guard !isRestoringSettings else { return }
            saveSettings()
            notifyConfigurationsChanged()
        }
    }

    @Published var blockTrackersEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var blockCosmeticElementsEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var fingerprintProtectionEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var allowlistedDomains: Set<String> = [] {
        didSet {
            guard !isRestoringSettings else { return }
            saveSettings()
            recompileAllowlist()
        }
    }

    @Published var strictPopupBlockedDomains: Set<String> = [] {
        didSet {
            saveSettings()
        }
    }

    @Published var fingerprintDisabledDomains: Set<String> = [] {
        didSet {
            saveSettings()
        }
    }

    @Published var httpsOnlyModeEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var dntEnabled: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published var clearDataOnQuit: Bool = false {
        didSet {
            saveSettings()
        }
    }

    @Published var strictCanvasBlockEnabled: Bool = false {
        didSet {
            saveSettings()
        }
    }

    @Published var copyCleanURLAutomatically: Bool = true {
        didSet {
            saveSettings()
        }
    }

    @Published private(set) var isReady: Bool = false

    // MARK: - WebKit Rule Lists

    private var baseRuleList: WKContentRuleList?
    private var allowlistRuleList: WKContentRuleList?
    private let ruleStore = WKContentRuleListStore.default()
    private var isCompilingBaseRules = false
    private var isCompilingAllowlist = false

    // Weak storage of active configurations to refresh rules when toggled
    private var activeControllers = NSHashTable<WKUserContentController>.weakObjects()

    // MARK: - Initialization

    private init() {
        loadSettings()
        compileBaseRules()
        recompileAllowlist()
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        isRestoringSettings = true
        defer { isRestoringSettings = false }

        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let settings = try? JSONDecoder().decode(ContentBlockerSettings.self, from: data) {
            self.isAdBlockingEnabled = settings.isAdBlockingEnabled
            self.blockTrackersEnabled = settings.blockTrackersEnabled
            self.blockCosmeticElementsEnabled = settings.blockCosmeticElementsEnabled
            self.fingerprintProtectionEnabled = settings.fingerprintProtectionEnabled
            self.allowlistedDomains = settings.allowlistedDomains
            self.strictPopupBlockedDomains = settings.strictPopupBlockedDomains
            self.fingerprintDisabledDomains = settings.fingerprintDisabledDomains
            self.httpsOnlyModeEnabled = settings.httpsOnlyModeEnabled
            self.dntEnabled = settings.dntEnabled
            self.clearDataOnQuit = settings.clearDataOnQuit
            self.strictCanvasBlockEnabled = settings.strictCanvasBlockEnabled
            self.copyCleanURLAutomatically = settings.copyCleanURLAutomatically
        } else {
            self.isAdBlockingEnabled = true
            self.blockTrackersEnabled = true
            self.blockCosmeticElementsEnabled = true
            self.fingerprintProtectionEnabled = true
            self.allowlistedDomains = []
            self.strictPopupBlockedDomains = []
            self.fingerprintDisabledDomains = []
            self.httpsOnlyModeEnabled = true
            self.dntEnabled = true
            self.clearDataOnQuit = false
            self.strictCanvasBlockEnabled = false
            self.copyCleanURLAutomatically = true
        }
    }

    private func saveSettings() {
        guard !isRestoringSettings else { return }
        let settings = ContentBlockerSettings(
            isAdBlockingEnabled: isAdBlockingEnabled,
            blockTrackersEnabled: blockTrackersEnabled,
            blockCosmeticElementsEnabled: blockCosmeticElementsEnabled,
            fingerprintProtectionEnabled: fingerprintProtectionEnabled,
            allowlistedDomains: allowlistedDomains,
            strictPopupBlockedDomains: strictPopupBlockedDomains,
            fingerprintDisabledDomains: fingerprintDisabledDomains,
            httpsOnlyModeEnabled: httpsOnlyModeEnabled,
            dntEnabled: dntEnabled,
            clearDataOnQuit: clearDataOnQuit,
            strictCanvasBlockEnabled: strictCanvasBlockEnabled,
            copyCleanURLAutomatically: copyCleanURLAutomatically
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    // MARK: - Rule Compilation

    /// Compiles or retrieves the base ad & tracking content rules.
    func compileBaseRules(completion: (() -> Void)? = nil) {
        guard !isCompilingBaseRules else { return }
        isCompilingBaseRules = true

        let json = ContentBlockerRules.generateDefaultRuleListJSON()
        ruleStore?.compileContentRuleList(
            forIdentifier: ContentBlockerRules.ruleListIdentifier,
            encodedContentRuleList: json
        ) { [weak self] ruleList, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCompilingBaseRules = false
                if let ruleList = ruleList {
                    self.baseRuleList = ruleList
                    self.isReady = true
                    self.refreshAllContentControllers()
                } else if let error = error {
                    print("[Shields] Error compiling base rule list: \(error)")
                }
                completion?()
            }
        }
    }

    /// Recompiles the dynamic allowlist rules whenever whitelisted domains change.
    private func recompileAllowlist() {
        guard let ruleStore = ruleStore else { return }
        guard !allowlistedDomains.isEmpty else {
            self.allowlistRuleList = nil
            self.refreshAllContentControllers()
            ruleStore.removeContentRuleList(forIdentifier: ContentBlockerRules.allowlistRuleListIdentifier) { _ in }
            return
        }

        guard !isCompilingAllowlist else { return }
        isCompilingAllowlist = true

        let json = ContentBlockerRules.generateAllowlistJSON(domains: allowlistedDomains)
        ruleStore.compileContentRuleList(
            forIdentifier: ContentBlockerRules.allowlistRuleListIdentifier,
            encodedContentRuleList: json
        ) { [weak self] ruleList, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCompilingAllowlist = false
                if let ruleList = ruleList {
                    self.allowlistRuleList = ruleList
                    self.refreshAllContentControllers()
                } else if let error = error {
                    print("[Shields] Error compiling allowlist: \(error)")
                }
            }
        }
    }

    // MARK: - WebKit Integration

    /// Applies content blocking rules to a newly constructed webview configuration.
    func apply(to configuration: WKWebViewConfiguration) {
        let userContentController = configuration.userContentController
        activeControllers.add(userContentController)

        guard isAdBlockingEnabled else { return }

        if let base = baseRuleList {
            userContentController.add(base)
        }
        if let allowlist = allowlistRuleList {
            userContentController.add(allowlist)
        }
    }

    /// Updates all live web content controllers when rules or global toggles change.
    private func refreshAllContentControllers() {
        for controller in activeControllers.allObjects {
            controller.removeAllContentRuleLists()
            guard isAdBlockingEnabled else { continue }
            if let base = baseRuleList {
                controller.add(base)
            }
            if let allowlist = allowlistRuleList {
                controller.add(allowlist)
            }
        }
    }

    private func notifyConfigurationsChanged() {
        refreshAllContentControllers()
    }

    // MARK: - Shield State Queries & Mutations

    /// Returns true if Shields is actively protecting the given URL.
    func isShieldActive(for url: URL?) -> Bool {
        guard isAdBlockingEnabled else { return false }
        guard let url = url, !url.isLotusPage else { return false }
        guard let host = DomainNormalizer.normalize(url: url) else { return true }
        return !allowlistedDomains.contains(host)
    }

    /// Toggles allowlist status for the domain of the given URL.
    /// Returns the new protection state (true if active, false if allowlisted/disabled).
    @discardableResult
    func toggleShield(for url: URL?) -> Bool {
        guard let url = url, let host = DomainNormalizer.normalize(url: url) else {
            return isAdBlockingEnabled
        }

        if allowlistedDomains.contains(host) {
            allowlistedDomains.remove(host)
            return true
        } else {
            allowlistedDomains.insert(host)
            return false
        }
    }

    /// Removes a domain from the allowlist.
    func removeAllowlistDomain(_ domain: String) {
        let normalized = DomainNormalizer.normalize(host: domain)
        allowlistedDomains.remove(normalized)
    }

    /// Adds a domain to the allowlist.
    func addAllowlistDomain(_ domain: String) {
        let normalized = DomainNormalizer.normalize(host: domain)
        guard !normalized.isEmpty else { return }
        allowlistedDomains.insert(normalized)
    }

    // MARK: - Strict Popup & Link Shield

    /// Returns true if strict popup/link blocking is enabled for the given URL.
    func isStrictPopupBlockingActive(for url: URL?) -> Bool {
        guard let url = url, !url.isLotusPage else { return false }
        guard let host = DomainNormalizer.normalize(url: url) else { return false }
        return strictPopupBlockedDomains.contains(host)
    }

    /// Toggles strict popup/link blocking for the domain of the given URL.
    @discardableResult
    func toggleStrictPopupBlocking(for url: URL?) -> Bool {
        guard let url = url, let host = DomainNormalizer.normalize(url: url) else {
            return false
        }
        if strictPopupBlockedDomains.contains(host) {
            strictPopupBlockedDomains.remove(host)
            return false
        } else {
            strictPopupBlockedDomains.insert(host)
            return true
        }
    }

    /// Explicitly enables or disables strict popup/link blocking for the given domain.
    func setStrictPopupBlocking(for domain: String, enabled: Bool) {
        let normalized = DomainNormalizer.normalize(host: domain)
        guard !normalized.isEmpty else { return }
        if enabled {
            strictPopupBlockedDomains.insert(normalized)
        } else {
            strictPopupBlockedDomains.remove(normalized)
        }
    }

    // MARK: - Per-Site Fingerprint Protection

    /// Returns true if fingerprint protection is actively protecting the given URL.
    func isFingerprintProtectionActive(for url: URL?) -> Bool {
        guard fingerprintProtectionEnabled else { return false }
        guard let url = url, !url.isLotusPage else { return false }
        guard isShieldActive(for: url) else { return false }
        guard let host = DomainNormalizer.normalize(url: url) else { return true }
        return !fingerprintDisabledDomains.contains(host)
    }

    /// Toggles fingerprint protection for the domain of the given URL.
    @discardableResult
    func toggleFingerprintProtection(for url: URL?) -> Bool {
        guard let url = url, let host = DomainNormalizer.normalize(url: url) else {
            return fingerprintProtectionEnabled
        }
        if fingerprintDisabledDomains.contains(host) {
            fingerprintDisabledDomains.remove(host)
            return true
        } else {
            fingerprintDisabledDomains.insert(host)
            return false
        }
    }

    /// Explicitly sets fingerprint protection for the given domain.
    func setFingerprintProtection(for domain: String, enabled: Bool) {
        let normalized = DomainNormalizer.normalize(host: domain)
        guard !normalized.isEmpty else { return }
        if enabled {
            fingerprintDisabledDomains.remove(normalized)
        } else {
            fingerprintDisabledDomains.insert(normalized)
        }
    }
}

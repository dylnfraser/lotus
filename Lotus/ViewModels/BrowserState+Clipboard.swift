//
//  BrowserState+Clipboard.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/23/26.
//

import AppKit
import SwiftUI
import WebKit

struct URLCopyFeedback: Equatable {
    enum Outcome: Equatable {
        case copied
        case cleanCopied
        case failed
    }

    let id: UUID
    let tabId: UUID
    let outcome: Outcome

    var message: String {
        switch outcome {
        case .copied:
            return "URL copied to clipboard"
        case .cleanCopied:
            return "Clean URL copied"
        case .failed:
            return "Couldn't copy URL"
        }
    }

    var systemImage: String {
        switch outcome {
        case .copied, .cleanCopied:
            return "link"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
}

extension BrowserState {

    // MARK: - Tracking Parameter Stripping

    private static let trackingQueryParameters: Set<String> = [
        "utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content",
        "utm_id", "utm_source_platform", "utm_creative_format", "utm_marketing_tactic",
        "fbclid", "gclid", "gclsrc", "dclid", "wbraid", "gbraid",
        "msclkid", "twclid", "igshid", "mc_eid", "yclid", "_hsenc", "_hsmi",
        "mkt_tok", "ref", "ref_src", "ref_url", "si", "feature", "sr_share"
    ]

    /// Strips common marketing, affiliate, tracking, and analytics query parameters from a URL.
    static func cleanURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        if let queryItems = components.queryItems, !queryItems.isEmpty {
            let filtered = queryItems.filter { item in
                let name = item.name.lowercased()
                if trackingQueryParameters.contains(name) { return false }
                if name.hasPrefix("utm_") { return false }
                return true
            }

            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        return components.url ?? url
    }

    // MARK: - Clipboard

    /// Copies the active top-level page URL. If `copyCleanURLAutomatically` is enabled,
    /// tracking parameters are automatically stripped.
    func copyCurrentPageURL() {
        copyPageURL(for: selectedTabId)
    }

    /// Explicitly copies the clean URL (without tracking parameters) regardless of setting.
    func copyCleanPageURL(for tabId: UUID) {
        copyPageURL(for: tabId, forceClean: true)
    }

    func copyPageURL(for tabId: UUID? = nil, forceClean: Bool = false) {
        let id = tabId ?? selectedTabId
        guard let currentURL = webViewStore[id]?.url ?? url(for: id) ?? tab(for: id)?.url else {
            return
        }

        let shouldClean = forceClean || ContentBlockerService.shared.copyCleanURLAutomatically
        let urlToCopy = (!currentURL.isLotusPage && shouldClean) ? Self.cleanURL(from: currentURL) : currentURL

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(urlToCopy.absoluteString, forType: .string)

        let outcome: URLCopyFeedback.Outcome
        if didCopy {
            outcome = (!currentURL.isLotusPage && shouldClean) ? .cleanCopied : .copied
        } else {
            outcome = .failed
        }

        presentURLCopyFeedback(for: id, outcome: outcome)
    }

    private func presentURLCopyFeedback(for tabId: UUID, outcome: URLCopyFeedback.Outcome) {
        urlCopyFeedbackDismissalWorkItem?.cancel()

        let feedback = URLCopyFeedback(id: UUID(), tabId: tabId, outcome: outcome)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            urlCopyFeedback = feedback
        }

        let dismissal = DispatchWorkItem { [weak self] in
            guard self?.urlCopyFeedback?.id == feedback.id else { return }
            withAnimation(.easeInOut(duration: 0.20)) {
                self?.urlCopyFeedback = nil
            }
        }
        urlCopyFeedbackDismissalWorkItem = dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25, execute: dismissal)
    }
}

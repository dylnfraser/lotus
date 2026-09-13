//
//  WebTabContainerView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import WebKit

struct WebTabContainerView: NSViewRepresentable {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isInternalLotusPage: Bool {
        let url = browserState.url(for: activeTabId)
        return url?.isLotusPage == true
    }

    func makeNSView(context: Context) -> WebTabHostNSView {
        let hostView = WebTabHostNSView()
        if isInternalLotusPage {
            hostView.detachActiveWebView()
        } else {
            hostView.updateActiveWebView(browserState.getWebView(for: activeTabId))
        }
        return hostView
    }

    func updateNSView(_ nsView: WebTabHostNSView, context: Context) {
        if isInternalLotusPage {
            nsView.detachActiveWebView()
        } else {
            nsView.updateActiveWebView(browserState.getWebView(for: activeTabId))
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: WebTabHostNSView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

final class WebTabHostNSView: NSView {
    private var currentWebView: WKWebView?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.autoresizesSubviews = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func detachActiveWebView() {
        guard let webView = currentWebView else { return }
        webView.isHidden = true
        webView.removeFromSuperview()
        currentWebView = nil
    }

    func updateActiveWebView(_ newWebView: WKWebView) {
        let isTabSwitch = newWebView !== currentWebView

        if isTabSwitch {
            newWebView.wantsLayer = true
            newWebView.autoresizingMask = [.width, .height]

            if newWebView.superview != self {
                newWebView.isHidden = false
                addSubview(newWebView)
            } else {
                addSubview(newWebView, positioned: .above, relativeTo: nil)
            }

            if bounds.width > 0 && bounds.height > 0 {
                newWebView.frame = bounds
            }
            newWebView.isHidden = false
            currentWebView = newWebView

            for subview in subviews {
                if subview !== newWebView {
                    subview.removeFromSuperview()
                }
            }

            applyBoundsToSubviews()

            DispatchQueue.main.async { [weak self, weak newWebView] in
                guard let self = self, let wv = newWebView, !wv.isHidden else { return }
                let win = wv.window ?? self.window ?? NSApp.keyWindow
                if let responder = win?.firstResponder, (responder is NSTextView || responder is NSTextField) {
                    return
                }
                win?.makeFirstResponder(wv)
            }
        } else {
            if newWebView.isHidden {
                newWebView.isHidden = false
            }
            applyBoundsToSubviews()
        }
    }

    override func layout() {
        super.layout()
        applyBoundsToSubviews()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyBoundsToSubviews()
        if let currentWebView = currentWebView, !currentWebView.isHidden {
            let win = self.window ?? NSApp.keyWindow
            if let responder = win?.firstResponder, (responder is NSTextView || responder is NSTextField) {
                return
            }
            win?.makeFirstResponder(currentWebView)
        }
    }

    private func applyBoundsToSubviews() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        for subview in subviews {
            if subview.frame != bounds {
                subview.frame = bounds
            }
        }
    }
}

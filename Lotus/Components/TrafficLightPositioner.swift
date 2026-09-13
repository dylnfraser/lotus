//
//  TrafficLightPositioner.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI
import AppKit

struct TrafficLightPositioner: NSViewRepresentable {
    let leading: CGFloat
    let top: CGFloat
    let isVisible: Bool

    init(leading: CGFloat = 20, top: CGFloat = 20, isVisible: Bool = true) {
        self.leading = leading
        self.top = top
        self.isVisible = isVisible
    }

    func makeNSView(context: Context) -> NSView {
        let view = PositionerView()
        view.leading = leading
        view.top = top
        view.isVisible = isVisible
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let posView = nsView as? PositionerView {
            posView.leading = leading
            posView.top = top
            posView.isVisible = isVisible
            posView.reposition()
        }
    }
}

private final class PositionerView: NSView {
    var leading: CGFloat = 20
    var top: CGFloat = 20
    var isVisible: Bool = true
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupWindow()
    }

    private func setupWindow() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()

        guard let window = self.window else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        reposition()

        let resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.reposition()
        }
        observers.append(resizeObserver)

        if let closeButton = window.standardWindowButton(.closeButton),
           let titlebarView = closeButton.superview {
            titlebarView.postsFrameChangedNotifications = true
            let frameObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: titlebarView,
                queue: .main
            ) { [weak self] _ in
                self?.reposition()
            }
            observers.append(frameObserver)
        }

        DispatchQueue.main.async { [weak self] in
            self?.reposition()
        }
    }

    func reposition() {
        guard let window = self.window,
              !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let min = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let titlebar = close.superview else {
            return
        }

        close.isHidden = !isVisible
        min.isHidden = !isVisible
        zoom.isHidden = !isVisible

        guard isVisible else { return }

        let buttonHeight = close.frame.height
        let buttonWidth = close.frame.width
        let spacing: CGFloat = 9

        let y: CGFloat
        if titlebar.isFlipped {
            y = top
        } else {
            y = titlebar.frame.height - top - buttonHeight
        }

        close.frame.origin = CGPoint(x: leading, y: y)
        min.frame.origin = CGPoint(x: leading + buttonWidth + spacing, y: y)
        zoom.frame.origin = CGPoint(x: leading + (buttonWidth + spacing) * 2, y: y)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

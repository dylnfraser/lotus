//
//  FindBarView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// A Chrome-style floating find-in-page bar positioned in the top-right corner of
/// the active web page container.
struct FindBarView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    @FocusState private var isFieldFocused: Bool
    @State private var isPrevHovered: Bool = false
    @State private var isNextHovered: Bool = false
    @State private var isCloseHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.50) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPlaceholder: Color {
        colorScheme == .dark ? .white.opacity(0.38) : Color(nsColor: .placeholderTextColor)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.09)
    }

    private var hasMatches: Bool {
        browserState.findTotalMatches > 0
    }

    private var isQueryEmpty: Bool {
        browserState.findQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(foregroundSecondary)
                .frame(width: 16)

            // Search input field
            TextField(
                "",
                text: Binding(
                    get: { browserState.findQuery },
                    set: { browserState.updateFindQuery($0, for: activeTabId) }
                ),
                prompt: Text("Find in page").foregroundColor(foregroundPlaceholder)
            )
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(foregroundPrimary)
            .textFieldStyle(.plain)
            .lineLimit(1)
            .focused($isFieldFocused)
            .frame(maxWidth: .infinity)
            .onKeyPress(.return, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.shift) {
                    browserState.findPrevious(for: activeTabId)
                } else {
                    browserState.findNext(for: activeTabId)
                }
                return .handled
            }
            .onKeyPress(.escape) {
                browserState.closeFind(for: activeTabId)
                return .handled
            }
            .onExitCommand {
                browserState.closeFind(for: activeTabId)
            }
            .onKeyPress(.tab) {
                return .handled
            }

            // Match counter
            ZStack(alignment: .trailing) {
                if !isQueryEmpty {
                    Text(hasMatches ? "\(browserState.findCurrentMatch)/\(browserState.findTotalMatches)" : "0/0")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(hasMatches ? foregroundSecondary : Color(nsColor: .systemRed).opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(hasMatches ? (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)) : Color(nsColor: .systemRed).opacity(0.12))
                        )
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 32, alignment: .trailing)

            // Vertical divider
            Rectangle()
                .fill(cardStroke)
                .frame(width: 1, height: 18)
                .padding(.horizontal, 2)

            // Navigation and Close buttons
            HStack(spacing: 3) {
                // Previous button (chevron.up)
                Button {
                    browserState.findPrevious(for: activeTabId)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(hasMatches ? (isPrevHovered ? foregroundPrimary : foregroundSecondary) : foregroundSecondary.opacity(0.35))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isPrevHovered && hasMatches ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasMatches)
                .help("Previous match (⇧⌘G, ⇧↩)")
                .onHover { isPrevHovered = $0 }

                // Next button (chevron.down)
                Button {
                    browserState.findNext(for: activeTabId)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(hasMatches ? (isNextHovered ? foregroundPrimary : foregroundSecondary) : foregroundSecondary.opacity(0.35))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isNextHovered && hasMatches ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasMatches)
                .help("Next match (⌘G, ↩)")
                .onHover { isNextHovered = $0 }

                // Close button (xmark)
                Button {
                    browserState.closeFind(for: activeTabId)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isCloseHovered ? foregroundPrimary : foregroundSecondary)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isCloseHovered ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
                .onHover { isCloseHovered = $0 }
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .frame(width: 330)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow, state: .active)
                (colorScheme == .dark ? Color.black.opacity(0.28) : Color(nsColor: .windowBackgroundColor).opacity(0.72))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.40 : 0.15), radius: 16, x: 0, y: 6)
        .onAppear {
            focusAndSelectField()
        }
        .onChange(of: browserState.findFocusTrigger) {
            focusAndSelectField()
        }
        .onDisappear {
            browserState.clearFindHighlights(for: activeTabId)
        }
    }

    private func focusAndSelectField() {
        isFieldFocused = true
        DispatchQueue.main.async {
            isFieldFocused = true
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }
}

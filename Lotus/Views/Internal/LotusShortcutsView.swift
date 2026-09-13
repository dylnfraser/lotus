//
//  LotusShortcutsView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit

struct LotusShortcutsView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    @ObservedObject private var shortcutManager = ShortcutManager.shared
    @State private var searchText: String = ""
    @Environment(\.colorScheme) private var colorScheme

    private var totalShortcutsCount: Int {
        ShortcutManager.categories.reduce(0) { $0 + $1.items.count }
    }

    private var filteredCategories: [ShortcutCategory] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ShortcutManager.categories
        }
        let q = trimmed.lowercased()
        return ShortcutManager.categories.compactMap { cat in
            let matchingItems = cat.items.filter {
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.defaultDisplay.localizedCaseInsensitiveContains(q) ||
                (shortcutManager.customShortcut(for: $0.id)?.displayString.localizedCaseInsensitiveContains(q) ?? false)
            }
            guard !matchingItems.isEmpty else { return nil }
            return ShortcutCategory(id: cat.id, title: cat.title, items: matchingItems)
        }
    }

    // MARK: - Colors

    private var activeAccentColor: Color {
        if !browserState.isPrivate {
            if browserState.currentProfile.color == .grey {
                return Color(nsColor: .controlAccentColor)
            }
            return browserState.currentProfile.color.color
        }
        let accent = LotusAccentColor(rawValue: UserDefaults.standard.string(forKey: "lotus.browser.accentColor") ?? "white") ?? .white
        return accent.color
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPlaceholder: Color {
        colorScheme == .dark ? .white.opacity(0.40) : Color(nsColor: .placeholderTextColor)
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : Color(nsColor: .controlBackgroundColor)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    private var separatorColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.06)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 4)

                    if filteredCategories.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(filteredCategories) { category in
                            categorySection(category)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .background(
            (colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color(nsColor: .windowBackgroundColor))
                .ignoresSafeArea()
        )
        .transaction { $0.animation = nil }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(foregroundPrimary)

                    Text("\(totalShortcutsCount) shortcuts\(shortcutManager.overrides.isEmpty ? "" : " • \(shortcutManager.overrides.count) customized")")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }

                Spacer()

                if !shortcutManager.overrides.isEmpty {
                    LotusHeaderActionButton(
                        title: "Reset All",
                        systemImage: "arrow.counterclockwise",
                        isDestructive: false
                    ) {
                        shortcutManager.resetAll()
                    }
                }
            }

            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search shortcuts").foregroundColor(foregroundPlaceholder)
                )
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(foregroundPrimary)
                .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(foregroundSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: ShortcutCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(foregroundPrimary)
                .padding(.leading, 2)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    ShortcutRowView(
                        item: item,
                        isAlternate: index % 2 == 1,
                        shortcutManager: shortcutManager
                    )

                    if index < category.items.count - 1 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "keyboard")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(foregroundSecondary.opacity(0.5))

            Text("No results found")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(foregroundSecondary)

            Text("Try a different search term")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(foregroundSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shortcut Row View

private struct ShortcutRowView: View {
    let item: ShortcutMetadata
    let isAlternate: Bool
    @ObservedObject var shortcutManager: ShortcutManager

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var rowHoverFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035)
    }

    private var alternateRowFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.025)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(foregroundPrimary)
                .lineLimit(1)

            Spacer()

            ShortcutRecorderPill(
                actionId: item.id,
                defaultDisplay: item.defaultDisplay,
                shortcutManager: shortcutManager
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(isHovered ? rowHoverFill : (isAlternate ? alternateRowFill : Color.clear))
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .contentShape(Rectangle())
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Shortcut Recorder Pill

struct ShortcutRecorderPill: View {
    let actionId: String
    let defaultDisplay: String
    @ObservedObject var shortcutManager: ShortcutManager
    @State private var isRecording: Bool = false
    @State private var localMonitor: Any? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var currentDisplay: String {
        shortcutManager.customShortcut(for: actionId)?.displayString ?? defaultDisplay
    }

    private var isOverridden: Bool {
        shortcutManager.customShortcut(for: actionId) != nil
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: 4) {
                    if isRecording {
                        Text("Press keys…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    } else {
                        Text(currentDisplay)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(isOverridden ? .accentColor : (colorScheme == .dark ? .white.opacity(0.85) : .primary))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.15) : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Click or press Esc to cancel" : "Click to rebind shortcut")

            if isOverridden {
                Button {
                    shortcutManager.resetOverride(id: actionId)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default (\(defaultDisplay))")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 53 { // Escape cancels recording
                stopRecording()
                return nil
            }

            let hasCmd = flags.contains(.command)
            let hasOpt = flags.contains(.option)
            let hasCtrl = flags.contains(.control)
            let hasShift = flags.contains(.shift)

            // Require at least one modifier key for valid shortcuts
            guard hasCmd || hasOpt || hasCtrl || hasShift else {
                return nil
            }

            var specialKey: String? = nil
            var keyChar = ""
            switch event.keyCode {
            case 123: specialKey = "leftArrow"
            case 124: specialKey = "rightArrow"
            case 125: specialKey = "downArrow"
            case 126: specialKey = "upArrow"
            case 48: specialKey = "tab"
            case 36, 76: specialKey = "return"
            case 51: specialKey = "delete"
            default:
                if let chars = event.charactersIgnoringModifiers?.lowercased(), let first = chars.first {
                    keyChar = String(first)
                }
            }

            if specialKey != nil || !keyChar.isEmpty {
                let data = CustomShortcutData(
                    keyChar: keyChar,
                    isSpecialKey: specialKey,
                    command: hasCmd,
                    shift: hasShift,
                    option: hasOpt,
                    control: hasCtrl
                )
                shortcutManager.setOverride(id: actionId, shortcut: data)
                stopRecording()
                return nil
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}



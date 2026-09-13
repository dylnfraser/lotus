//
//  ShortcutsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

struct ShortcutsSettingsSection: View {
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

    var body: some View {
        VStack(spacing: 16) {
            // Search and Toolbar Actions
            HStack(spacing: 10) {
                SettingsInputField(
                    placeholder: "Search shortcuts…",
                    text: $searchText,
                    systemImage: "magnifyingglass"
                )

                if !shortcutManager.overrides.isEmpty {
                    LotusSettingsButton(
                        title: "Reset All",
                        systemImage: "arrow.counterclockwise"
                    ) {
                        shortcutManager.resetAll()
                    }
                }
            }

            if filteredCategories.isEmpty {
                SettingsSectionCard {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.secondary)
                        Text("No shortcuts found")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                ForEach(filteredCategories) { category in
                    SettingsSectionCard(title: category.title) {
                        ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                            SettingsShortcutRow(
                                item: item,
                                shortcutManager: shortcutManager
                            )

                            if index < category.items.count - 1 {
                                SettingsDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings Shortcut Row

private struct SettingsShortcutRow: View {
    let item: ShortcutMetadata
    @ObservedObject var shortcutManager: ShortcutManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)
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
    }
}

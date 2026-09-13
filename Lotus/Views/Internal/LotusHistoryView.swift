//
//  LotusHistoryView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

// MARK: - Models

struct HistorySection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [HistoryItem]
}

// MARK: - Grouping Helper

private enum HistoryGrouping {
    static func filterAndGroup(
        from entries: [HistoryItem],
        query: String,
        limit: Int
    ) -> (sections: [HistorySection], totalFilteredCount: Int) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [HistoryItem]
        if trimmed.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.url.absoluteString.localizedCaseInsensitiveContains(trimmed) ||
                ($0.displayHost?.localizedCaseInsensitiveContains(trimmed) == true)
            }
        }

        let totalCount = filtered.count
        guard totalCount > 0 else {
            return (sections: [], totalFilteredCount: 0)
        }

        let sorted = filtered.sorted { $0.visitedAt > $1.visitedAt }
        let windowed = Array(sorted.prefix(limit))

        let calendar = Calendar.current
        let now = Date()

        var dayMap: [Date: [HistoryItem]] = [:]
        for item in windowed {
            let day = calendar.startOfDay(for: item.visitedAt)
            dayMap[day, default: []].append(item)
        }

        let sortedDays = dayMap.keys.sorted(by: >)
        var sections: [HistorySection] = []

        for day in sortedDays {
            guard let itemsInDay = dayMap[day], !itemsInDay.isEmpty else { continue }
            let dayTitle = LotusDateFormatter.dayLabel(for: day, relativeTo: now, calendar: calendar)
            sections.append(HistorySection(
                id: "\(day.timeIntervalSinceReferenceDate)",
                title: dayTitle,
                items: itemsInDay
            ))
        }

        return (sections: sections, totalFilteredCount: totalCount)
    }
}

// MARK: - Main View

struct LotusHistoryView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    @State private var searchText: String = ""
    @State private var selectedIds: Set<UUID> = []
    @State private var selectionAnchorId: UUID?
    @State private var sections: [HistorySection] = []
    @State private var totalFilteredCount: Int = 0
    @State private var displayLimit: Int = 60
    @State private var lastClickedId: UUID? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isSelecting: Bool {
        !selectedIds.isEmpty
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

    @State private var searchDebounceTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 22) {
                    headerSection
                        .padding(.top, 32)
                        .padding(.bottom, 4)

                    if sections.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        ForEach(sections) { section in
                            daySection(section)
                        }

                        if totalFilteredCount > displayLimit {
                            Color.clear
                                .frame(height: 32)
                                .onAppear {
                                    displayLimit += 60
                                    refreshSections()
                                }
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
        .onAppear {
            refreshSections()
        }
        .onChange(of: browserState.historyEntries) { _, entries in
            let valid = Set(entries.map { $0.id })
            selectedIds = selectedIds.intersection(valid)
            refreshSections()
        }
        .onChange(of: browserState.currentProfileId) { _, _ in
            refreshSections()
        }
        .onChange(of: searchText) { _, _ in
            displayLimit = 60
            refreshSections(debounce: true)
        }
        .onDeleteCommand {
            guard !selectedIds.isEmpty else { return }
            browserState.historyConfirmation = .deleteSelected(ids: selectedIds)
        }
        .background {
            DeleteKeyMonitor {
                guard !selectedIds.isEmpty else { return }
                browserState.historyConfirmation = .deleteSelected(ids: selectedIds)
            }
            .frame(width: 0, height: 0)
        }
    }

    private var activeProfileId: UUID {
        if let tabId = tabId, let tab = browserState.tab(for: tabId) {
            return tab.profileId ?? browserState.defaultProfileId
        }
        return browserState.currentProfileId
    }

    private func refreshSections(debounce: Bool = false) {
        searchDebounceTask?.cancel()

        let entries = browserState.historyEntries(for: activeProfileId)
        let query = searchText
        let limit = displayLimit

        if debounce {
            searchDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled else { return }

                let result = await Task.detached(priority: .userInitiated) {
                    HistoryGrouping.filterAndGroup(
                        from: entries,
                        query: query,
                        limit: limit
                    )
                }.value

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.sections = result.sections
                    self.totalFilteredCount = result.totalFilteredCount
                }
            }
        } else {
            Task.detached(priority: .userInitiated) {
                let result = HistoryGrouping.filterAndGroup(
                    from: entries,
                    query: query,
                    limit: limit
                )
                await MainActor.run {
                    self.sections = result.sections
                    self.totalFilteredCount = result.totalFilteredCount
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(foregroundPrimary)

                    let count = browserState.historyEntries(for: activeProfileId).count
                    Text("\(count) \(count == 1 ? "page" : "pages") visited")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if isSelecting {
                        LotusHeaderActionButton(
                            title: "Delete \(selectedIds.count)",
                            systemImage: "trash",
                            isDestructive: true
                        ) {
                            browserState.historyConfirmation = .deleteSelected(ids: selectedIds)
                        }

                        LotusHeaderActionButton(title: "Cancel", systemImage: nil, isDestructive: false) {
                            selectedIds.removeAll()
                        }
                    } else if !browserState.historyEntries(for: activeProfileId).isEmpty {
                        LotusHeaderActionButton(title: "Clear All", systemImage: nil, isDestructive: false) {
                            browserState.historyConfirmation = .clearAll(totalCount: browserState.historyEntries(for: activeProfileId).count)
                        }
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
                    prompt: Text("Search history").foregroundColor(foregroundPlaceholder)
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

    // MARK: - Day Section

    private func daySection(_ section: HistorySection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(foregroundPrimary)
                .padding(.leading, 2)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, entry in
                    HistoryRowView(
                        entry: entry,
                        isAlternate: index % 2 == 1,
                        isSelected: selectedIds.contains(entry.id),
                        isSelecting: isSelecting,
                        onToggleSelect: { toggleSelection(entry.id) },
                        onDelete: {
                            browserState.historyConfirmation = .deleteSelected(ids: [entry.id])
                        },
                        onClick: {
                            if NSEvent.modifierFlags.contains(.shift) {
                                selectRange(to: entry.id)
                            } else if isSelecting {
                                toggleSelection(entry.id)
                            } else if NSEvent.modifierFlags.contains(.command) {
                                browserState.openTabFromCmdClick(sourceTabId: activeTabId, title: entry.title, url: entry.url, select: false)
                            } else {
                                browserState.loadURL(entry.url, in: activeTabId)
                            }
                        }
                    )

                    if index < section.items.count - 1 {
                        Rectangle()
                            .fill(separatorColor)
                            .frame(height: 1)
                            .padding(.leading, 46)
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

    // MARK: - Selection

    private func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
        selectionAnchorId = id
    }

    private func selectRange(to id: UUID) {
        let orderedItems = sections.flatMap(\.items)
        guard let targetIndex = orderedItems.firstIndex(where: { $0.id == id }) else { return }

        guard let anchorId = selectionAnchorId,
              let anchorIndex = orderedItems.firstIndex(where: { $0.id == anchorId }) else {
            selectedIds.insert(id)
            selectionAnchorId = id
            return
        }

        let range = orderedItems[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)]
        selectedIds.formUnion(range.map(\.id))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(foregroundSecondary.opacity(0.5))

            if searchText.isEmpty {
                Text("No browsing history")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Pages you visit will appear here")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.7))
            } else {
                Text("No results found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Try a different search term")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History Row View

private struct HistoryRowView: View {
    let entry: HistoryItem
    let isAlternate: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let onToggleSelect: () -> Void
    let onDelete: () -> Void
    let onClick: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor)
    }

    private var rowHoverFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035)
    }

    private var alternateRowFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.10) : Color.black.opacity(0.025)
    }

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 12) {
                // Leading: Favicon or selection checkbox
                ZStack {
                    if isSelecting || isHovered {
                        SelectionCheckbox(isSelected: isSelected, action: onToggleSelect)
                    } else {
                        CachedFaviconView(
                            url: entry.faviconURL,
                            defaultSystemName: "globe",
                            fallbackColor: foregroundSecondary,
                            size: 16
                        )
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.title.isEmpty ? (entry.displayHost ?? entry.url.absoluteString) : entry.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary.opacity(isSelected ? 1.0 : 0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let host = entry.displayHost {
                        Text(host)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 12)

                if isHovered && !isSelecting {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Delete from History")
                    .transition(.opacity)
                }

                Text(LotusDateFormatter.relativeTime(for: entry.visitedAt))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.75))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle()
                    .fill(isSelected
                        ? Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10)
                        : (isHovered ? rowHoverFill : (isAlternate ? alternateRowFill : Color.clear)))
            )
            .animation(.easeInOut(duration: 0.14), value: isHovered)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if isHovered != hovering {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Selection Checkbox

private struct SelectionCheckbox: View {
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : foregroundSecondary.opacity(0.6), lineWidth: 1.5)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}



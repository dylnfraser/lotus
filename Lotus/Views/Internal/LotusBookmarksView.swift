//
//  LotusBookmarksView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Models

struct BookmarkSection: Identifiable, Equatable {
    let id: String
    let title: String
    let items: [BookmarkItem]
}

// MARK: - Grouping Helper

private enum BookmarkGrouping {
    static func filterAndGroup(
        from entries: [BookmarkItem],
        query: String
    ) -> (sections: [BookmarkSection], totalFilteredCount: Int) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [BookmarkItem]
        if trimmed.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed) ||
                $0.url.absoluteString.localizedCaseInsensitiveContains(trimmed) ||
                $0.displayDomain.localizedCaseInsensitiveContains(trimmed)
            }
        }

        let totalCount = filtered.count
        guard totalCount > 0 else {
            return (sections: [], totalFilteredCount: 0)
        }

        let sorted = filtered.sorted { $0.createdAt > $1.createdAt }
        let calendar = Calendar.current
        let now = Date()

        var dayMap: [Date: [BookmarkItem]] = [:]
        for item in sorted {
            let day = calendar.startOfDay(for: item.createdAt)
            dayMap[day, default: []].append(item)
        }

        let sortedDays = dayMap.keys.sorted(by: >)
        var sections: [BookmarkSection] = []

        for day in sortedDays {
            guard let itemsInDay = dayMap[day], !itemsInDay.isEmpty else { continue }
            let dayTitle = LotusDateFormatter.dayLabel(for: day, relativeTo: now, calendar: calendar)
            sections.append(BookmarkSection(
                id: "\(day.timeIntervalSinceReferenceDate)",
                title: dayTitle,
                items: itemsInDay
            ))
        }

        return (sections: sections, totalFilteredCount: totalCount)
    }
}

// MARK: - Main View

struct LotusBookmarksView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    @State private var searchText: String = ""
    @State private var selectedIds: Set<UUID> = []
    @State private var selectionAnchorId: UUID?
    @State private var sections: [BookmarkSection] = []
    @State private var totalFilteredCount: Int = 0
    @State private var isAddSheetPresented: Bool = false
    @State private var editingBookmark: BookmarkItem? = nil

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
        .sheet(isPresented: $isAddSheetPresented) {
            AddBookmarkSheet(browserState: browserState, profileId: activeProfileId)
        }
        .sheet(item: $editingBookmark) { item in
            EditBookmarkSheet(browserState: browserState, bookmark: item)
        }
        .onAppear {
            refreshSections()
        }
        .onChange(of: browserState.bookmarks) { _, entries in
            let valid = Set(entries.map { $0.id })
            selectedIds = selectedIds.intersection(valid)
            refreshSections()
        }
        .onChange(of: browserState.currentProfileId) { _, _ in
            refreshSections()
        }
        .onChange(of: searchText) { _, _ in
            refreshSections()
        }
        .onDeleteCommand {
            guard !selectedIds.isEmpty else { return }
            deleteSelected()
        }
    }

    private var activeProfileId: UUID {
        if let tabId = tabId, let tab = browserState.tab(for: tabId) {
            return tab.profileId ?? browserState.defaultProfileId
        }
        return browserState.currentProfileId
    }

    private func refreshSections() {
        let result = BookmarkGrouping.filterAndGroup(
            from: browserState.bookmarks(for: activeProfileId),
            query: searchText
        )
        sections = result.sections
        totalFilteredCount = result.totalFilteredCount
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bookmarks")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(foregroundPrimary)

                    let count = browserState.bookmarks(for: activeProfileId).count
                    Text("\(count) \(count == 1 ? "bookmark" : "bookmarks") saved")
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
                            deleteSelected()
                        }

                        LotusHeaderActionButton(title: "Cancel", systemImage: nil, isDestructive: false) {
                            selectedIds.removeAll()
                        }
                    } else {
                        LotusHeaderActionButton(title: "Export", systemImage: "square.and.arrow.up", isDestructive: false) {
                            exportBookmarks()
                        }

                        LotusHeaderActionButton(title: "Add Bookmark", systemImage: "plus", isDestructive: false) {
                            isAddSheetPresented = true
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
                    prompt: Text("Search bookmarks").foregroundColor(foregroundPlaceholder)
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

    private func daySection(_ section: BookmarkSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(foregroundPrimary)
                .padding(.leading, 2)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, entry in
                    BookmarkRowView(
                        entry: entry,
                        isAlternate: index % 2 == 1,
                        isSelected: selectedIds.contains(entry.id),
                        isSelecting: isSelecting,
                        onToggleSelect: { toggleSelection(entry.id) },
                        onEdit: { editingBookmark = entry },
                        onDelete: {
                            browserState.bookmarkConfirmation = .deleteSingle(bookmark: entry)
                        },
                        onOpenInNewTab: {
                            browserState.openTab(at: entry.url, title: entry.title)
                        },
                        onClick: {
                            if NSEvent.modifierFlags.contains(.shift) {
                                selectRange(to: entry.id)
                            } else if isSelecting {
                                toggleSelection(entry.id)
                            } else if NSEvent.modifierFlags.contains(.command) {
                                _ = browserState.openTabFromCmdClick(sourceTabId: activeTabId, title: entry.title, url: entry.url, select: false)
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

    private func deleteSelected() {
        guard !selectedIds.isEmpty else { return }
        browserState.bookmarkConfirmation = .deleteSelected(count: selectedIds.count, ids: selectedIds)
    }

    private func exportBookmarks() {
        let html = browserState.exportBookmarksHTML(profileId: activeProfileId)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.html]
        savePanel.nameFieldStringValue = "Lotus Bookmarks.html"
        savePanel.begin { result in
            if result == .OK, let targetURL = savePanel.url {
                try? html.write(to: targetURL, atomically: true, encoding: .utf8)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(foregroundSecondary.opacity(0.5))

            if searchText.isEmpty {
                Text("No bookmarks yet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Press ⌘D or click the bookmark button in the address bar to bookmark pages")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(foregroundSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
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

// MARK: - Bookmark Row View

private struct BookmarkRowView: View {
    let entry: BookmarkItem
    let isAlternate: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let onToggleSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onOpenInNewTab: () -> Void
    let onClick: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
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
                        BookmarkSelectionCheckbox(isSelected: isSelected, action: onToggleSelect)
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
                    Text(entry.title.isEmpty ? entry.displayDomain : entry.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary.opacity(isSelected ? 1.0 : 0.92))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(entry.displayDomain)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if isHovered && !isSelecting {
                    HStack(spacing: 4) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(foregroundSecondary)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                        }
                        .buttonStyle(.plain)
                        .help("Edit Bookmark")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color(nsColor: .systemRed).opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .help("Delete Bookmark")
                    }
                }

                Text(LotusDateFormatter.relativeTime(for: entry.createdAt))
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
        .contextMenu {
            Button("Open in Current Tab") {
                onClick()
            }

            Button("Open in New Tab") {
                onOpenInNewTab()
            }

            Divider()

            Button("Edit…") {
                onEdit()
            }

            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.url.absoluteString, forType: .string)
            }

            Divider()

            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Bookmark Selection Checkbox

private struct BookmarkSelectionCheckbox: View {
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
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



// MARK: - Add Bookmark Sheet

private struct AddBookmarkSheet: View {
    @ObservedObject var browserState: BrowserState
    var profileId: UUID? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var urlString: String = "https://"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Bookmark")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Title").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("Page Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Spacer()
                LotusDialogCancelButton { dismiss() }

                LotusDialogActionButton(title: "Add", isDestructive: false, showsReturnKeycap: true) {
                    save()
                    dismiss()
                }
                .disabled(title.isEmpty || URL(string: urlString) == nil)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 360)
    }

    private func save() {
        guard let url = URL(string: urlString) else { return }
        browserState.addOrUpdateBookmark(
            title: title,
            url: url,
            profileId: profileId
        )
    }
}

// MARK: - Edit Bookmark Sheet

private struct EditBookmarkSheet: View {
    @ObservedObject var browserState: BrowserState
    let bookmark: BookmarkItem
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var urlString: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Bookmark")
                .font(.system(size: 15, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Title").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("Page Title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("URL").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("https://example.com", text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 10) {
                Spacer()
                LotusDialogCancelButton { dismiss() }

                LotusDialogActionButton(title: "Save Changes", isDestructive: false, showsReturnKeycap: true) {
                    save()
                    dismiss()
                }
                .disabled(title.isEmpty || URL(string: urlString) == nil)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            title = bookmark.title
            urlString = bookmark.url.absoluteString
        }
    }

    private func save() {
        guard let url = URL(string: urlString) else { return }
        browserState.removeBookmark(id: bookmark.id)
        browserState.addOrUpdateBookmark(
            title: title,
            url: url,
            faviconURL: bookmark.faviconURL,
            profileId: bookmark.profileId
        )
    }
}

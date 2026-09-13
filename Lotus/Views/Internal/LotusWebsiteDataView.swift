//
//  LotusWebsiteDataView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI
import AppKit
import WebKit

struct LotusWebsiteDataView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil

    @State private var records: [WKWebsiteDataRecord] = []
    @State private var isLoading: Bool = true
    @State private var searchText: String = ""
    @State private var selectedDomainNames: Set<String> = []
    @State private var selectionAnchorName: String?
    @Environment(\.colorScheme) private var colorScheme

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var isSelecting: Bool {
        !selectedDomainNames.isEmpty
    }

    private var filteredRecords: [WKWebsiteDataRecord] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sorted = records.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        if trimmed.isEmpty {
            return sorted
        }
        return sorted.filter { record in
            record.displayName.lowercased().contains(trimmed) ||
            dataTypesSummary(for: record).contains(where: { $0.lowercased().contains(trimmed) })
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

                    if isLoading {
                        loadingState
                            .padding(.top, 60)
                    } else if filteredRecords.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    } else {
                        recordsSection

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
            refreshRecords()
        }
        .onDeleteCommand {
            guard !selectedDomainNames.isEmpty else { return }
            browserState.websiteDataConfirmation = .deleteSelected(domains: selectedDomainNames)
        }
        .background {
            DeleteKeyMonitor {
                guard !selectedDomainNames.isEmpty else { return }
                browserState.websiteDataConfirmation = .deleteSelected(domains: selectedDomainNames)
            }
            .frame(width: 0, height: 0)
        }
    }

    private func refreshRecords() {
        isLoading = records.isEmpty
        browserState.fetchWebsiteDataRecords { fetched in
            records = fetched
            let valid = Set(fetched.map { $0.displayName })
            selectedDomainNames = selectedDomainNames.intersection(valid)
            isLoading = false
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Website Data")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(foregroundPrimary)

                    Text(isLoading ? "Scanning storage…" : "\(records.count) site\(records.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(foregroundSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if isSelecting {
                        LotusHeaderActionButton(
                            title: "Delete \(selectedDomainNames.count)",
                            systemImage: "trash",
                            isDestructive: true
                        ) {
                            browserState.websiteDataConfirmation = .deleteSelected(domains: selectedDomainNames)
                        }

                        LotusHeaderActionButton(title: "Cancel", systemImage: nil, isDestructive: false) {
                            selectedDomainNames.removeAll()
                        }
                    } else if !records.isEmpty {
                        LotusHeaderActionButton(title: "Clear All", systemImage: nil, isDestructive: false) {
                            browserState.websiteDataConfirmation = .clearAll(totalCount: records.count)
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
                    prompt: Text("Search website data").foregroundColor(foregroundPlaceholder)
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

    // MARK: - Records Section

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stored Sites")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(foregroundPrimary)
                .padding(.leading, 2)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(filteredRecords.enumerated()), id: \.element.displayName) { index, record in
                    WebsiteDataRowView(
                        record: record,
                        dataTypes: dataTypesSummary(for: record),
                        isAlternate: index % 2 == 1,
                        isSelected: selectedDomainNames.contains(record.displayName),
                        isSelecting: isSelecting,
                        onToggleSelect: { toggleSelection(record.displayName) },
                        onDelete: {
                            browserState.websiteDataConfirmation = .deleteSelected(domains: [record.displayName])
                        },
                        onClick: {
                            if NSEvent.modifierFlags.contains(.shift) {
                                selectRange(to: record.displayName)
                            } else if isSelecting {
                                toggleSelection(record.displayName)
                            } else if NSEvent.modifierFlags.contains(.command) {
                                if let url = URL(string: "https://\(record.displayName)") {
                                    browserState.openTabFromCmdClick(sourceTabId: activeTabId, title: record.displayName, url: url, select: false)
                                }
                            } else {
                                if let url = URL(string: "https://\(record.displayName)") {
                                    browserState.loadURL(url, in: activeTabId)
                                }
                            }
                        },
                        onOpenInNewTab: {
                            if let url = URL(string: "https://\(record.displayName)") {
                                browserState.openTabFromCmdClick(sourceTabId: activeTabId, title: record.displayName, url: url, select: true)
                            }
                        }
                    )

                    if index < filteredRecords.count - 1 {
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

    private func toggleSelection(_ domain: String) {
        if selectedDomainNames.contains(domain) {
            selectedDomainNames.remove(domain)
        } else {
            selectedDomainNames.insert(domain)
        }
        selectionAnchorName = domain
    }

    private func selectRange(to domain: String) {
        guard let targetIndex = filteredRecords.firstIndex(where: { $0.displayName == domain }) else { return }

        guard let anchorName = selectionAnchorName,
              let anchorIndex = filteredRecords.firstIndex(where: { $0.displayName == anchorName }) else {
            selectedDomainNames.insert(domain)
            selectionAnchorName = domain
            return
        }

        let range = filteredRecords[min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)]
        selectedDomainNames.formUnion(range.map(\.displayName))
    }

    // MARK: - Empty & Loading States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Scanning website storage…")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(foregroundSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(foregroundSecondary.opacity(0.5))

            if searchText.isEmpty {
                Text("No stored website data")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(foregroundSecondary)

                Text("Websites that store cookies, cache, or local data will appear here")
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

    private func dataTypesSummary(for record: WKWebsiteDataRecord) -> [String] {
        var summary: [String] = []
        let types = record.dataTypes
        if types.contains(WKWebsiteDataTypeCookies) { summary.append("Cookies") }
        if types.contains(WKWebsiteDataTypeLocalStorage) { summary.append("Local Storage") }
        if types.contains(WKWebsiteDataTypeIndexedDBDatabases) { summary.append("IndexedDB") }
        if types.contains(WKWebsiteDataTypeDiskCache) || types.contains(WKWebsiteDataTypeMemoryCache) { summary.append("Cache") }
        if types.contains(WKWebsiteDataTypeServiceWorkerRegistrations) { summary.append("Service Workers") }
        if types.contains(WKWebsiteDataTypeSessionStorage) { summary.append("Session Storage") }
        return summary.isEmpty ? ["Data"] : summary
    }
}

// MARK: - Website Data Row View

private struct WebsiteDataRowView: View {
    let record: WKWebsiteDataRecord
    let dataTypes: [String]
    let isAlternate: Bool
    let isSelected: Bool
    let isSelecting: Bool
    let onToggleSelect: () -> Void
    let onDelete: () -> Void
    let onClick: () -> Void
    let onOpenInNewTab: () -> Void

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

    private var domainFaviconURL: URL? {
        URL(string: "https://\(record.displayName)/favicon.ico")
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
                            url: domainFaviconURL,
                            defaultSystemName: "globe",
                            fallbackColor: foregroundSecondary,
                            size: 16
                        )
                    }
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(foregroundPrimary.opacity(isSelected ? 1.0 : 0.92))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 4) {
                        ForEach(dataTypes, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(foregroundSecondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                                )
                        }
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
                    .help("Delete stored data for \(record.displayName)")
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
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
            Button("Open Website") {
                onClick()
            }

            Button("Open in New Tab") {
                onOpenInNewTab()
            }

            Divider()

            Button("Copy Domain Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(record.displayName, forType: .string)
            }

            Divider()

            Button("Delete Stored Data", role: .destructive) {
                onDelete()
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



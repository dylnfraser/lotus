//
//  LotusSettingsView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct LotusSettingsView: View {
    @ObservedObject var browserState: BrowserState
    var tabId: UUID? = nil
    var initialCategory: SettingsCategory = .general
    @ObservedObject private var contentBlocker = ContentBlockerService.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: SettingsCategory
    @AppStorage("lotus.browser.accentColor") private var accentColorKey: String = "white"

    init(browserState: BrowserState, tabId: UUID? = nil, initialCategory: SettingsCategory = .general) {
        self.browserState = browserState
        self.tabId = tabId
        self.initialCategory = initialCategory
        _selectedCategory = State(initialValue: initialCategory)
    }

    private var activeTabId: UUID {
        tabId ?? browserState.selectedTabId
    }

    private var activeAccentColor: Color {
        if !browserState.isPrivate {
            if browserState.currentProfile.color == .grey {
                return Color(nsColor: .controlAccentColor)
            }
            return browserState.currentProfile.color.color
        }
        let accent = LotusAccentColor(rawValue: accentColorKey) ?? .white
        return accent.color
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // Hero Profile Avatar & Palette Swatches
                heroHeader
                    .padding(.top, 28)
                    .padding(.bottom, 22)

                // Category Pill Tabs
                categoryPillsBar
                    .padding(.bottom, 24)

                // Content Container (Max width 620pt matching Dia)
                VStack(alignment: .leading, spacing: 18) {
                    // Category Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedCategory.title)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(foregroundPrimary)

                        Text(selectedCategory.subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                    }
                    .padding(.bottom, 6)

                    // Active Section
                    switch selectedCategory {
                    case .general:
                        GeneralSettingsSection()
                    case .appearance:
                        AppearanceSettingsSection(browserState: browserState)
                    case .profiles:
                        ProfilesSettingsSection(browserState: browserState, tabId: tabId)
                    case .bangs:
                        BangsSettingsSection(browserState: browserState)
                    case .scripts:
                        ScriptsSettingsSection(browserState: browserState)
                    case .tabs:
                        TabsSettingsSection(browserState: browserState)
                    case .media:
                        MediaSettingsSection(browserState: browserState)
                    case .shields:
                        ShieldsSettingsSection(contentBlocker: contentBlocker)
                    case .privacy:
                        PrivacySettingsSection(browserState: browserState, tabId: tabId, contentBlocker: contentBlocker)
                    case .downloads:
                        DownloadsSettingsSection(browserState: browserState, tabId: tabId)
                    case .shortcuts:
                        ShortcutsSettingsSection(browserState: browserState, tabId: tabId)
                    case .about:
                        AboutSettingsSection(browserState: browserState)
                    }

                    Spacer(minLength: 64)
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .tint(activeAccentColor)
        .accentColor(activeAccentColor)
        .background(
            (colorScheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.09) : Color(nsColor: .windowBackgroundColor))
                .ignoresSafeArea()
        )
        .transaction { $0.animation = nil }
    }

    // MARK: - Hero Header (Avatar + Color Swatches)

    private var heroHeader: some View {
        VStack(spacing: 16) {
            // Profile Avatar Circle
            Button {
                browserState.openProfileEditor(for: browserState.currentProfile)
            } label: {
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        .frame(width: 76, height: 76)

                    if !browserState.currentProfile.icon.isEmpty {
                        Image(systemName: browserState.currentProfile.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(activeAccentColor)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 46, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.30))
                    }
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Edit Profile")

            // Centered 8-Swatch Palette
            SettingsColorSwatchesRow(selectedAccent: $accentColorKey, browserState: browserState)
        }
    }

    // MARK: - Category Pills Bar

    private var categoryPillsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SettingsCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                            Text(category.title)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        }
                        .foregroundColor(
                            isSelected
                                ? (colorScheme == .dark ? Color.white : Color.black)
                                : (colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.55))
                        )
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(
                                    isSelected
                                        ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08))
                                        : Color.clear
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: 680)
    }
}

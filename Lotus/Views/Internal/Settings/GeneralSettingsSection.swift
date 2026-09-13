//
//  GeneralSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

struct GeneralSettingsSection: View {
    @AppStorage("lotus.browser.startupBehavior") private var startupBehavior: String = "restore"
    @AppStorage("lotus.browser.searchEngine") private var searchEngine: String = "google"
    @AppStorage("lotus.browser.searchSuggestionsEnabled") private var searchSuggestionsEnabled: Bool = true
    @AppStorage("lotus.browser.warnOnQuit") private var warnOnQuit: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "System & Startup") {
                DefaultBrowserSettingsRow()
                SettingsDivider()
                SettingsPickerRow(
                    systemImage: "power",
                    title: "On startup",
                    subtitle: "Choose how Lotus opens when launched",
                    selection: $startupBehavior,
                    options: [
                        ("restore", "Restore Session"),
                        ("empty", "Command Palette"),
                        ("pinnedOnly", "Pinned Only")
                    ],
                    pickerWidth: 170
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "exclamationmark.triangle",
                    title: "Warn before quitting",
                    subtitle: "Show a confirmation prompt when pressing ⌘Q",
                    isOn: $warnOnQuit
                ) { newValue in
                    UserDefaults.standard.set(!newValue, forKey: BrowserState.alwaysQuitKey)
                }
            }

            SettingsSectionCard(
                title: "Default Search Engine",
                footer: "Search engine used when entering search queries into the address bar or command palette."
            ) {
                SearchEngineSettingsRow(searchEngine: $searchEngine)
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "text.magnifyingglass",
                    title: "Search suggestions",
                    subtitle: "Show live completions from search engine in command palette",
                    isOn: $searchSuggestionsEnabled
                )
            }
        }
    }
}

// MARK: - Rows

private struct DefaultBrowserSettingsRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDefault: Bool = false

    private func checkDefaultStatus() {
        if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com")!) {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.dylanfraser.Lotus"
            let defaultBundleId = Bundle(url: defaultAppURL)?.bundleIdentifier
            isDefault = (defaultBundleId == bundleId)
        } else {
            isDefault = false
        }
    }

    private func setAsDefault() {
        if #available(macOS 12.0, *) {
            let appURL = Bundle.main.bundleURL
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "http") { _ in
                DispatchQueue.main.async { checkDefaultStatus() }
            }
            NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: "https") { _ in
                DispatchQueue.main.async { checkDefaultStatus() }
            }
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            checkDefaultStatus()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Default web browser")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                Text(isDefault ? "Lotus is currently your default web browser" : "Set Lotus as your default browser for opening web links")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
            }

            Spacer()

            if isDefault {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Default")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            } else {
                LotusSettingsButton(title: "Set as Default…") {
                    setAsDefault()
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .onAppear(perform: checkDefaultStatus)
    }
}

private struct SearchEngineSettingsRow: View {
    @Binding var searchEngine: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded: Bool = false
    @State private var isAddSheetPresented: Bool = false
    @State private var newEngineName: String = ""
    @State private var newEngineShortcut: String = ""
    @State private var newEngineURLTemplate: String = ""
    @ObservedObject private var engineStore = CustomSearchEnginesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Search engine")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Default search engine for URL bar and command palette")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                Text(engineStore.engineName(for: searchEngine))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }

            if isExpanded {
                VStack(spacing: 8) {
                    SettingsDivider(leadingInset: 14)

                    HStack {
                        Text("Configured Engines")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()

                        LotusSettingsButton(title: "Add Custom Engine", systemImage: "plus") {
                            newEngineName = ""
                            newEngineShortcut = ""
                            newEngineURLTemplate = ""
                            isAddSheetPresented = true
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    VStack(spacing: 2) {
                        ForEach(engineStore.allEngines) { engine in
                            let isSelected = searchEngine.lowercased() == engine.id.lowercased()
                            HStack(spacing: 10) {
                                Image(systemName: engine.iconName)
                                    .font(.system(size: 12))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .secondary)
                                    .frame(width: 18)

                                Text(engine.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.85) : .primary)

                                if let shortcut = engine.shortcut, !shortcut.isEmpty {
                                    Text("(\(shortcut))")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                }

                                Spacer()

                                Text(engine.displayURL)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.40) : .secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.trailing, 8)

                                if engine.isCustom, let customId = engine.customId {
                                    Button {
                                        if searchEngine == engine.id {
                                            searchEngine = "google"
                                        }
                                        engineStore.removeEngine(id: customId)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 4)
                                    .help("Delete Custom Search Engine")
                                }

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                searchEngine = engine.id
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
        .sheet(isPresented: $isAddSheetPresented) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Custom Search Engine")
                    .font(.system(size: 16, weight: .semibold))

                Text("Enter a search engine name, optional shortcut (for !bangs), and URL template with {searchTerms} (or %s).")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    SettingsInputField(
                        placeholder: "Name (e.g. Perplexity)",
                        text: $newEngineName
                    )

                    SettingsInputField(
                        placeholder: "Shortcut (optional, e.g. px)",
                        text: $newEngineShortcut
                    )

                    SettingsInputField(
                        placeholder: "Search URL (e.g. https://www.perplexity.ai/search?q={searchTerms})",
                        text: $newEngineURLTemplate
                    )
                }

                HStack {
                    LotusSettingsButton(title: "Cancel") {
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    LotusSettingsButton(
                        title: "Add Engine",
                        isDisabled: newEngineName.trimmingCharacters(in: .whitespaces).isEmpty || newEngineURLTemplate.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        let cleanName = newEngineName.trimmingCharacters(in: .whitespaces)
                        let cleanShortcut = newEngineShortcut.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespaces))
                        let cleanURL = newEngineURLTemplate.trimmingCharacters(in: .whitespaces)
                        guard !cleanName.isEmpty, !cleanURL.isEmpty else { return }

                        engineStore.addEngine(
                            name: cleanName,
                            searchURLTemplate: cleanURL,
                            shortcut: cleanShortcut.isEmpty ? nil : cleanShortcut
                        )
                        isAddSheetPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420)
        }
    }
}

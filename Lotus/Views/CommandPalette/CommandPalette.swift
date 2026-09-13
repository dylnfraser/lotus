//
//  CommandPalette.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import Combine

/// Reference-backed state read by the AppKit event monitor. Unlike a captured
/// `View` value, this remains current as SwiftUI recreates `CommandPalette`.
private final class CommandPaletteDeleteKeyState: ObservableObject {
    @Published var unlockRequest: Int = 0
    var isProviderLocked: Bool = false
    var isQueryEmpty: Bool = true
}

/// The ⌘T command palette: a centered dialog over a blurred backdrop with a
/// URL/search field and live search-engine suggestions. Submitting opens a
/// new tab; no tab exists until then (Arc/Zen-style new-tab flow).
struct CommandPalette: View {
    @ObservedObject var browserState: BrowserState
    @StateObject private var suggestionService = SearchSuggestionService()
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedIndex: Int? = nil
    @State private var hoveredIndex: Int? = nil
    /// Locked site-search provider ("bang" mode) — queries go straight to
    /// the provider's search URL.
    @State private var activeProvider: SiteSearchProvider? = nil
    /// Local key monitor for backspace: SwiftUI's `onKeyPress(.delete)` is
    /// unreliable for backspace inside macOS text fields.
    @State private var deleteKeyMonitor: Any? = nil
    @StateObject private var deleteKeyState = CommandPaletteDeleteKeyState()
    @State private var isSubmitting: Bool = false
    @Namespace private var selectionNamespace
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("lotus.browser.centerCommandPaletteOverWebview") private var centerCommandPaletteOverWebview: Bool = false
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true

    private var paletteLeadingPadding: CGFloat {
        if centerCommandPaletteOverWebview {
            return browserState.isSidebarVisible ? browserState.sidebarWidth : (showsBrowserFrame ? 6 : 0)
        }
        return 0
    }

    private var paletteTrailingPadding: CGFloat {
        if centerCommandPaletteOverWebview {
            return showsBrowserFrame ? 6 : 0
        }
        return 0
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    private var foregroundPlaceholder: Color {
        colorScheme == .dark ? .white.opacity(0.40) : Color(nsColor: .placeholderTextColor)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var returnButtonBackground: Color {
        if let provider = activeProvider {
            return provider.accentColor
        }
        return colorScheme == .dark ? Color.white : Color.accentColor
    }

    private var returnButtonForeground: Color {
        if let provider = activeProvider {
            return provider.isAccentLight ? Color.black.opacity(0.80) : Color.white
        }
        return colorScheme == .dark ? Color.black.opacity(0.75) : Color.white
    }

    /// Capped list shown in the dropdown — fewer rows reads more native.
    private var visibleSuggestions: [SearchSuggestion] {
        Array(suggestionService.suggestions.prefix(6))
    }

    private var hasSuggestions: Bool {
        !visibleSuggestions.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Provider hinted while typing (exact trigger or trigger prefix),
    /// shown as a "⇥ Search …" badge until locked in.
    private var hintedProvider: SiteSearchProvider? {
        guard activeProvider == nil else { return nil }
        return SiteSearchProvider.match(for: searchText)
    }

    /// Inline ghost text remainder shown directly behind the cursor.
    private var ghostRemainder: String? {
        guard activeProvider == nil, selectedIndex == nil, !searchText.isEmpty else { return nil }
        return suggestionService.ghostRemainder(for: searchText, history: browserState.activeProfileHistoryEntries)
    }

    /// Full string for the active ghost autocomplete match.
    private var fullGhostMatch: String? {
        guard activeProvider == nil, selectedIndex == nil, !searchText.isEmpty else { return nil }
        return suggestionService.fullGhostMatch(for: searchText, history: browserState.activeProfileHistoryEntries)
    }

    var body: some View {
        ZStack {
            // Invisible click-catcher: dismisses the palette on click-outside
            // without blurring or dimming the window content.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    browserState.closeCommandPalette()
                }

            // Palette card, top-aligned so it only ever grows downward: the
            // field stays put while the attached suggestion list expands
            // beneath it, Spotlight-style.
            VStack(spacing: 0) {
                searchField

                if hasSuggestions {
                    Divider()
                        .overlay(cardStroke)

                    VStack(spacing: 2) {
                        ForEach(Array(visibleSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                            suggestionRow(suggestion, index: index)
                        }
                    }
                    // Uniform 6pt inset: with 10pt row corners this stays
                    // concentric with the card's 16pt radius, and 6+12pt row
                    // padding keeps icons aligned with the magnifying glass.
                    .padding(6)
                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: selectedIndex)
                }
            }
            .frame(width: 640)
            .background(
                ZStack {
                    VisualEffectView(material: .popover, blendingMode: .withinWindow, state: .active)
                    (colorScheme == .dark ? Color.black.opacity(0.25) : Color(nsColor: .windowBackgroundColor).opacity(0.65))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                // Outline shifts to the provider's brand color while a bang
                // is locked.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        activeProvider.map { $0.accentColor.opacity(colorScheme == .dark ? 0.70 : 0.60) } ?? cardStroke,
                        lineWidth: activeProvider != nil ? 1.5 : 1
                    )
            )
            // Ambient brand glow when bang is locked, similar to Arc
            .shadow(
                color: activeProvider.map { $0.accentColor.opacity(colorScheme == .dark ? 0.28 : 0.16) } ?? Color.clear,
                radius: 24,
                x: 0,
                y: 6
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 28, x: 0, y: 12)
            .animation(.easeInOut(duration: 0.15), value: activeProvider)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.leading, paletteLeadingPadding)
            .padding(.trailing, paletteTrailingPadding)
            .padding(.top, 200)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: browserState.isSidebarVisible)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: centerCommandPaletteOverWebview)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: showsBrowserFrame)
        }
        .transition(.asymmetric(
            insertion: .identity,
            removal: .opacity.animation(.easeOut(duration: 0.10))
        ))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(90)
        .onAppear {
            resetPalette()
            installDeleteKeyMonitor()
        }
        .onChange(of: browserState.isCommandPaletteOpen) { _, isOpen in
            // The view stays mounted during the close fade — reset on every
            // reopen so ⌘T always starts from an empty dialog.
            if isOpen {
                resetPalette()
            }
        }
        .onChange(of: isSearchFocused) { _, focused in
            // Focus watchdog: if something (e.g. the webview's deferred
            // first-responder pass) steals focus while the palette is open,
            // reclaim it once; if that doesn't stick by the next runloop
            // tick, dismiss the palette instead of leaving it stranded.
            guard !focused, browserState.isCommandPaletteOpen else { return }
            isSearchFocused = true
            DispatchQueue.main.async {
                if browserState.isCommandPaletteOpen && !isSearchFocused {
                    browserState.closeCommandPalette()
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            selectedIndex = nil
            deleteKeyState.isQueryEmpty = newValue.isEmpty
            if activeProvider == nil, newValue.hasSuffix(" "),
               let provider = SiteSearchProvider.exactMatch(for: newValue) {
                lockProvider(provider)
                return
            }
            let areSuggestionsEnabled = UserDefaults.standard.object(forKey: "lotus.browser.searchSuggestionsEnabled") as? Bool ?? true
            suggestionService.update(
                for: newValue,
                history: browserState.activeProfileHistoryEntries,
                bookmarks: browserState.activeProfileBookmarks,
                allowsRemoteSuggestions: activeProvider == nil && areSuggestionsEnabled,
                openTabs: browserState.activeProfileTabs
            )
        }
        .onChange(of: deleteKeyState.unlockRequest) { _, _ in
            guard activeProvider != nil else { return }
            unlockProvider()
        }
        .onDisappear {
            suggestionService.clear()
            if let monitor = deleteKeyMonitor {
                NSEvent.removeMonitor(monitor)
                deleteKeyMonitor = nil
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            // Magnifying glass: visible during standard search, hides when the bang pill enters
            if activeProvider == nil {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(foregroundSecondary)
                    .frame(width: 20)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }

            // Locked site-search badge, tinted with the provider's brand color
            if let provider = activeProvider {
                HStack(spacing: 6) {
                    Image(systemName: provider.iconName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(provider.name)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(provider.isAccentLight ? Color.black.opacity(0.85) : .white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(provider.accentColor.gradient)
                        .shadow(color: provider.accentColor.opacity(0.35), radius: 4, x: 0, y: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }

            ZStack(alignment: .leading) {
                // Inline Ghost Autocomplete Text (unified layout to eliminate character jump)
                if let ghost = ghostRemainder {
                    (
                        Text(searchText)
                            .foregroundColor(.clear)
                        +
                        Text(ghost)
                            .foregroundColor(foregroundPlaceholder.opacity(0.80))
                    )
                    .font(.system(size: 18, weight: .regular))
                    .allowsHitTesting(false)
                }

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text(activeProvider.map { "Search \($0.name)" } ?? "Search the web or type a URL")
                        .foregroundColor(foregroundPlaceholder)
                )
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(foregroundPrimary)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    submit()
                }
                .onKeyPress(.downArrow) {
                    guard !visibleSuggestions.isEmpty else { return .ignored }
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) {
                        if let current = selectedIndex {
                            selectedIndex = min(current + 1, visibleSuggestions.count - 1)
                        } else {
                            selectedIndex = 0
                        }
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    guard !visibleSuggestions.isEmpty else { return .ignored }
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) {
                        if let current = selectedIndex {
                            selectedIndex = current == 0 ? nil : current - 1
                        }
                    }
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if let full = fullGhostMatch, isSearchCaretAtEnd {
                        searchText = full
                        focusSearchField()
                        return .handled
                    }
                    if let current = selectedIndex, visibleSuggestions.indices.contains(current) {
                        searchText = visibleSuggestions[current].text
                        selectedIndex = nil
                        focusSearchField()
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) {
                    // Tab locks a hinted site-search provider before falling
                    // back to ghost completion or suggestion completion.
                    if let provider = hintedProvider {
                        lockProvider(provider)
                        return .handled
                    }
                    if let full = fullGhostMatch {
                        searchText = full
                        focusSearchField()
                        return .handled
                    }
                    if let current = selectedIndex, visibleSuggestions.indices.contains(current) {
                        searchText = visibleSuggestions[current].text
                        selectedIndex = nil
                        focusSearchField()
                        return .handled
                    } else if let first = visibleSuggestions.first {
                        searchText = first.text
                        selectedIndex = nil
                        focusSearchField()
                        return .handled
                    }
                    // Always consume Tab: letting it through triggers focus
                    // traversal, which silently moves focus out of the palette
                    // and leaves it stranded on screen.
                    return .handled
                }
                .onKeyPress(.escape) {
                    if activeProvider != nil {
                        unlockProvider()
                        return .handled
                    }
                    browserState.closeCommandPalette()
                    return .handled
                }
                .onExitCommand {
                    if activeProvider != nil {
                        unlockProvider()
                    } else {
                        browserState.closeCommandPalette()
                    }
                }
            }

            // Tab-to-search hint for a matched provider trigger
            if let provider = hintedProvider {
                HStack(spacing: 6) {
                    Text("⇥")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(foregroundSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                        )

                    Text("Search \(provider.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(foregroundSecondary)
                }
                .lineLimit(1)
                .fixedSize()
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }

            // Return hint — hidden until there's something to submit
            Image(systemName: "return")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(returnButtonForeground)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(returnButtonBackground)
                )
                .opacity(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeInOut(duration: 0.15), value: activeProvider)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: hintedProvider)
        // Fixed content height so the bang chip appearing/disappearing
        // never changes the bar's overall size.
        .frame(height: 28)
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .contentShape(Rectangle())
        .onTapGesture {
            focusSearchField()
        }
    }

    // MARK: - Suggestion Rows

    @ViewBuilder
    private func suggestionRow(_ suggestion: SearchSuggestion, index: Int) -> some View {
        let isSelected = selectedIndex == index
        let isRowHovered = hoveredIndex == index
        let isHighlighted = isSelected || isRowHovered
        let hasSubtitle = suggestion.subtitle != nil && suggestion.subtitle != suggestion.displayText

        Button {
            submitSuggestion(suggestion)
        } label: {
            HStack(spacing: 10) {
                Group {
                    if let favURL = suggestion.faviconURL ?? (suggestion.badgeText == "Jump to URL" ? faviconURL(for: suggestion.text) : nil) {
                        CachedFaviconView(
                            url: favURL,
                            defaultSystemName: suggestion.systemImage,
                            fallbackColor: isHighlighted ? foregroundPrimary : foregroundSecondary,
                            size: 16
                        )
                    } else {
                        Image(systemName: suggestion.systemImage)
                            .font(.system(size: 13, weight: isHighlighted ? .semibold : .regular))
                            .foregroundColor(isHighlighted ? foregroundPrimary : foregroundSecondary)
                    }
                }
                .frame(width: 20)
                .transaction { $0.animation = nil }

                HStack(spacing: 6) {
                    Text(suggestion.displayText)
                        .font(.system(size: 14))
                        .fontWeight(isHighlighted ? .semibold : .regular)
                        .foregroundColor(isHighlighted ? foregroundPrimary : foregroundPrimary.opacity(0.88))
                        .lineLimit(1)

                    if let subtitle = suggestion.subtitle, hasSubtitle {
                        Text("— \(subtitle)")
                            .font(.system(size: 12))
                            .fontWeight(isHighlighted ? .medium : .regular)
                            .foregroundColor(isHighlighted ? foregroundPrimary.opacity(0.70) : foregroundSecondary.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .truncationMode(.tail)
                .animation(.easeInOut(duration: 0.15), value: isHighlighted)

                Spacer(minLength: 8)

                if let badge = suggestion.badgeText {
                    Text(badge)
                        .font(.system(size: 11))
                        .fontWeight(isHighlighted ? .medium : .regular)
                        .foregroundColor(isHighlighted ? foregroundPrimary.opacity(0.85) : foregroundSecondary.opacity(0.70))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(minWidth: 70, idealWidth: 74, maxWidth: 100)
                        .frame(height: 18)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
                            )
                            .matchedGeometryEffect(id: "paletteSelectionCapsule", in: selectionNamespace)
                            .shadow(color: colorScheme == .dark ? Color.black.opacity(0.22) : Color.black.opacity(0.06), radius: 3.5, y: 1)
                    } else if isRowHovered {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
                            )
                            .transition(.opacity.animation(.easeInOut(duration: 0.12)))
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                hoveredIndex = index
            } else if hoveredIndex == index {
                hoveredIndex = nil
            }
        }
    }

    private func faviconURL(for input: String) -> URL? {
        guard let host = URLInputResolver.resolve(input)?.host, !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/favicon.ico"
        return components.url
    }

    // MARK: - Actions

    private func focusSearchField() {
        if !isSearchFocused {
            isSearchFocused = true
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    /// Clears all transient palette state so every ⌘T starts fresh. In
    /// edit-current-tab mode (⌘L / address-bar click) the field is prefilled
    /// with the tab's URL and fully selected for quick replacement.
    private func resetPalette() {
        isSubmitting = false
        activeProvider = nil
        selectedIndex = nil
        hoveredIndex = nil
        suggestionService.clear()
        if browserState.commandPaletteMode == .editCurrentTab, let url = browserState.activeURL {
            searchText = url.absoluteString
            focusSearchField()
            DispatchQueue.main.async {
                guard isSearchFocused else { return }
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
        } else {
            searchText = ""
            focusSearchField()
        }
        syncDeleteKeyMonitorState()
    }

    /// Unlocks the bang (like Escape) when backspace is pressed with an
    /// empty query or with the insertion point at the start of the line.
    private func installDeleteKeyMonitor() {
        guard deleteKeyMonitor == nil else { return }
        let monitorState = deleteKeyState
        deleteKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak monitorState] event in
            guard let monitorState = monitorState else { return event }
            guard event.keyCode == 51, // backspace
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  monitorState.isProviderLocked else {
                return event
            }
            if monitorState.isQueryEmpty {
                DispatchQueue.main.async {
                    monitorState.unlockRequest += 1
                }
                return nil
            }
            if let editor = NSApp.keyWindow?.firstResponder as? NSTextView,
               editor.selectedRange().location == 0,
               editor.selectedRange().length == 0 {
                DispatchQueue.main.async {
                    monitorState.unlockRequest += 1
                }
                return nil
            }
            return event
        }
    }

    private func lockProvider(_ provider: SiteSearchProvider) {
        activeProvider = provider
        searchText = ""
        selectedIndex = nil
        suggestionService.clear()
        syncDeleteKeyMonitorState()
        focusSearchField()
    }

    private func unlockProvider() {
        activeProvider = nil
        syncDeleteKeyMonitorState()
    }

    private func syncDeleteKeyMonitorState() {
        deleteKeyState.isProviderLocked = activeProvider != nil
        deleteKeyState.isQueryEmpty = searchText.isEmpty
    }

    /// Handles a tapped suggestion row — switches to the tab instantly if it's
    /// a tab suggestion, otherwise falls through to normal URL/search submit.
    private func submitSuggestion(_ suggestion: SearchSuggestion) {
        if suggestion.isTab, let tabId = suggestion.tabId {
            browserState.selectTab(tabId)
            browserState.closeCommandPalette()
            return
        }
        submit(with: suggestion.text)
    }

    private func submit(with text: String? = nil) {
        guard !isSubmitting, browserState.isCommandPaletteOpen else { return }

        // If the keyboard-Enter path lands on a tab suggestion, switch tabs immediately.
        if text == nil, let selected = selectedIndex, visibleSuggestions.indices.contains(selected) {
            let s = visibleSuggestions[selected]
            if s.isTab, let tabId = s.tabId {
                browserState.selectTab(tabId)
                browserState.closeCommandPalette()
                return
            }
        }

        let resolved: String
        if let text {
            resolved = text
        } else if let selected = selectedIndex, visibleSuggestions.indices.contains(selected) {
            resolved = visibleSuggestions[selected].text
        } else {
            resolved = searchText
        }
        let trimmed = resolved.trimmingCharacters(in: .whitespacesAndNewlines)

        // Locked site-search mode: route the query straight to the provider.
        // An empty query opens the site's homepage.
        if let provider = activeProvider {
            let url = trimmed.isEmpty ? provider.homepageURL : provider.searchURL(for: trimmed)
            guard let url else { return }
            isSubmitting = true
            finishSubmit(url: url, title: provider.name)
            return
        }

        guard !trimmed.isEmpty else { return }

        // Full bang submissions ("!yt lofi beats") work without locking.
        if let bang = SiteSearchProvider.parseBang(trimmed) {
            let url = bang.query.isEmpty ? bang.provider.homepageURL : bang.provider.searchURL(for: bang.query)
            guard let url else { return }
            isSubmitting = true
            finishSubmit(url: url, title: bang.provider.name)
            return
        }

        // `openTab(with:)` and `navigateActiveTab(to:)` intentionally ignore
        // unresolvable input. Validate before latching submission so Return
        // stays usable when that happens.
        guard URLInputResolver.resolve(trimmed) != nil else { return }
        isSubmitting = true
        suggestionService.clear()
        selectedIndex = nil
        if browserState.commandPaletteMode == .editCurrentTab {
            browserState.navigateActiveTab(to: trimmed)
            browserState.closeCommandPalette()
        } else {
            browserState.openTab(with: trimmed)
        }
    }

    /// Routes a fully-resolved URL according to the palette mode: replace
    /// the current tab's page, or open a new tab.
    private func finishSubmit(url: URL, title: String) {
        suggestionService.clear()
        selectedIndex = nil
        if browserState.commandPaletteMode == .editCurrentTab {
            browserState.loadURL(url, in: browserState.selectedTabId)
            browserState.closeCommandPalette()
        } else {
            browserState.openTab(at: url, title: title)
        }
    }

    private var isSearchCaretAtEnd: Bool {
        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        let selection = editor.selectedRange()
        return selection.length == 0 && selection.location == searchText.utf16.count
    }
}

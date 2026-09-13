//
//  SettingsSharedComponents.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

enum SettingsCategoryGroup: String, CaseIterable, Identifiable {
    case general = "General"
    case security = "Privacy & Security"
    case tools = "Tools & Advanced"

    var id: String { rawValue }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General & Search"
    case appearance = "Appearance"
    case tabs = "Tabs & Sidebar"
    case profiles = "Profiles"
    case bangs = "Search Bangs"
    case scripts = "Scripts & Styles"
    case shields = "Shields & Blocking"
    case privacy = "Privacy & Data"
    case downloads = "Downloads"
    case media = "Media & Performance"
    case shortcuts = "Shortcuts"
    case about = "About"

    var id: String { rawValue }

    var group: SettingsCategoryGroup {
        switch self {
        case .general, .appearance, .tabs, .profiles, .bangs, .scripts:
            return .general
        case .shields, .privacy, .downloads:
            return .security
        case .media, .shortcuts, .about:
            return .tools
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .profiles: return "person.crop.circle.fill"
        case .tabs: return "sidebar.left"
        case .bangs: return "bolt.fill"
        case .scripts: return "curlybraces"
        case .media: return "play.tv.fill"
        case .shields: return "shield.fill"
        case .privacy: return "lock.shield.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .shortcuts: return "keyboard.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconBackground: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .appearance: return Color(nsColor: .systemPurple)
        case .profiles: return Color(nsColor: .systemOrange)
        case .tabs: return Color(nsColor: .systemBlue)
        case .bangs: return Color(nsColor: .systemYellow)
        case .scripts: return Color(nsColor: .systemPurple)
        case .shields: return Color(nsColor: .systemRed)
        case .privacy: return Color(nsColor: .systemIndigo)
        case .downloads: return Color(nsColor: .systemTeal)
        case .media: return Color(nsColor: .systemGreen)
        case .shortcuts: return Color(nsColor: .systemPink)
        case .about: return Color(nsColor: .systemGray)
        }
    }

    var title: String {
        switch self {
        case .general: return "General & Search"
        case .appearance: return "Appearance"
        case .tabs: return "Tabs & Sidebar"
        case .profiles: return "Profiles"
        case .bangs: return "Search Bangs"
        case .scripts: return "Scripts & Styles"
        case .shields: return "Shields & Blocking"
        case .privacy: return "Privacy & Data"
        case .downloads: return "Downloads"
        case .media: return "Media & Performance"
        case .shortcuts: return "Keyboard Shortcuts"
        case .about: return "About Lotus"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Default browser, startup behavior, and search engine preferences"
        case .appearance: return "Theme, window framing, accent colors, and toolbar layout"
        case .tabs: return "Tab strip behavior, automatic grouping, and inactive tab archiving"
        case .profiles: return "Independent profile spaces with separate cookies, tabs, and logins"
        case .bangs: return "Direct site search shortcuts using prefixes like !yt, !gh, !w, !r or custom search engines"
        case .scripts: return "Custom CSS stylesheets and JavaScript snippets injected on matching domains"
        case .shields: return "Tracker blocking, cosmetic filtering, and custom element zapper"
        case .privacy: return "Browsing history, cookie management, and connection security"
        case .downloads: return "File download directory, tidy filenames, and download logs"
        case .media: return "Autoplay restrictions, Picture-in-Picture, and memory saver"
        case .shortcuts: return "Key bindings, hotkeys, and quick navigation actions"
        case .about: return "Browser version details, user agent configuration, and diagnostics"
        }
    }
}

// MARK: - Accent Colors

enum LotusAccentColor: String, CaseIterable, Identifiable {
    case white = "white"
    case blue = "blue"
    case purple = "purple"
    case pink = "pink"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .white: return "Monochrome"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        }
    }

    static var systemAccentColor: Color {
        Color(nsColor: .controlAccentColor)
    }

    var color: Color {
        switch self {
        case .white:
            return Color(nsColor: .controlAccentColor)
        case .blue:
            return FolderColor.blue.color
        case .purple:
            return FolderColor.purple.color
        case .pink:
            return FolderColor.pink.color
        case .red:
            return FolderColor.red.color
        case .orange:
            return FolderColor.orange.color
        case .yellow:
            return FolderColor.yellow.color
        case .green:
            return FolderColor.green.color
        }
    }

    var swatchColor: Color {
        switch self {
        case .white:
            return Color.primary
        default:
            return color
        }
    }

    var folderColorEquivalent: FolderColor {
        switch self {
        case .white: return .grey
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        }
    }

    var hexString: String {
        switch self {
        case .white:
            if let rgbColor = NSColor.controlAccentColor.usingColorSpace(.sRGB) {
                return String(format: "#%02X%02X%02X", Int(rgbColor.redComponent * 255), Int(rgbColor.greenComponent * 255), Int(rgbColor.blueComponent * 255))
            }
            return "#007AFF"
        case .blue: return "#007AFF"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        }
    }

    static var current: LotusAccentColor {
        let key = UserDefaults.standard.string(forKey: "lotus.browser.accentColor") ?? "white"
        return LotusAccentColor(rawValue: key) ?? .white
    }

    static var currentAccentHex: String {
        current.hexString
    }

    static var paletteOrder: [LotusAccentColor] {
        [.white, .green, .blue, .purple, .yellow, .pink, .red, .orange]
    }
}

extension FolderColor {
    var accentColorEquivalent: LotusAccentColor {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .grey: return .white
        }
    }
}

// MARK: - Sidebar Item (macOS & Arc/Dia Style)

struct SettingsSidebarItem: View {
    let category: SettingsCategory
    let isSelected: Bool
    var accentColor: Color? = nil
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var activeAccent: Color {
        accentColor ?? Color(nsColor: .controlAccentColor)
    }

    private var isAccentLight: Bool {
        if let accent = accentColor {
            return accent == FolderColor.yellow.color
        }
        return false
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                // Vibrant macOS-style squircle badge icon
                ZStack {
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(category.iconBackground.gradient)
                        .frame(width: 20, height: 20)

                    Image(systemName: category.systemImage)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(category.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(
                        isSelected
                            ? (isAccentLight ? Color.black : Color.white)
                            : (colorScheme == .dark ? Color.white.opacity(0.92) : Color(nsColor: .labelColor))
                    )
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(isSelected ? activeAccent : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Section Card (Dia/Arc Sleek Card with 14pt Radius & Hairline Border)

struct SettingsSectionCard<Content: View>: View {
    let title: String?
    let footer: String?
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, footer: String? = nil, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.footer = footer
        self.systemImage = systemImage
        self.content = content
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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                    .padding(.leading, 2)
                    .padding(.top, 14)
                    .padding(.bottom, 2)
            }

            VStack(spacing: 0, content: content)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(cardStroke, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let footer = footer, !footer.isEmpty {
                Text(footer)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor))
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Divider (Subtle Inset Separator)

struct SettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    var leadingInset: CGFloat = 16

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05))
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

// MARK: - Card Action Row (Dia-Style Prominent Button Card Row)

struct SettingsCardActionRow: View {
    var systemImage: String? = nil
    let title: String
    let subtitle: String
    var linkTitle: String? = nil
    var linkURL: URL? = nil
    let buttonTitle: String
    var buttonAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(nsColor: .labelColor))

                HStack(spacing: 4) {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.55) : Color(nsColor: .secondaryLabelColor))
                        .lineSpacing(2)

                    if let link = linkTitle, let url = linkURL {
                        Link(link, destination: url)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.accentColor)
                            .underline()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Button(action: buttonAction) {
                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings Prompt Box (Dia-Style Dark Text Area / Input)

struct SettingsPromptBox: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isMultiLine: Bool = true
    var minHeight: CGFloat = 38

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : Color(nsColor: .labelColor))

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(
                                isFocused
                                    ? (colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.20))
                                    : (colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)),
                                lineWidth: 1
                            )
                    )

                if isMultiLine {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.32) : Color.black.opacity(0.35))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $text)
                            .font(.system(size: 12, weight: .regular))
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .frame(minHeight: minHeight)
                            .focused($isFocused)
                    }
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(height: minHeight)
                        .focused($isFocused)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Settings Input Field (Matches LotusSettingsButton styling)

struct SettingsInputField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    var width: CGFloat? = nil
    var height: CGFloat = 30
    var onCommit: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool
    @State private var isHovered: Bool = false

    private var backgroundFill: Color {
        if isFocused {
            return colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)
        }
        return colorScheme == .dark
            ? Color.white.opacity(isHovered ? 0.09 : 0.06)
            : Color.black.opacity(isHovered ? 0.06 : 0.04)
    }

    private var strokeColor: Color {
        if isFocused {
            return colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.20)
        }
        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor))
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(nsColor: .labelColor))
                .focused($isFocused)
                .onSubmit {
                    onCommit?()
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: height)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.14), value: isFocused)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Settings Color Swatches Row (Centered Dia-Style Hero Swatches)

struct SettingsColorSwatchesRow: View {
    @Binding var selectedAccent: String
    var browserState: BrowserState? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(LotusAccentColor.paletteOrder) { accent in
                let isSelected = selectedAccent == accent.rawValue
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        selectedAccent = accent.rawValue
                        if let bs = browserState, !bs.isPrivate {
                            var updated = bs.currentProfile
                            updated.color = accent.folderColorEquivalent
                            bs.updateProfile(updated)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent.swatchColor)
                            .frame(width: 32, height: 32)

                        if isSelected {
                            Circle()
                                .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.85), lineWidth: 2)
                                .frame(width: 42, height: 42)
                        }
                    }
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(accent.displayName)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Generic Settings Row

struct SettingsRow: View {
    let systemImage: String?
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme

    init(systemImage: String? = nil, title: String, detail: String) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : Color(nsColor: .labelColor))

            Spacer()

            Text(detail)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor))
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
    }
}

// MARK: - Untinted Dropdown Extension

extension View {
    func untintedDropdown() -> some View {
        self
            .pickerStyle(.menu)
            .tint(Color(nsColor: .controlTextColor))
            .accentColor(Color(nsColor: .controlTextColor))
            .foregroundColor(Color(nsColor: .controlTextColor))
    }
}

// MARK: - Reusable Settings Rows

struct SettingsToggleRow: View {
    var systemImage: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    var customAction: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: subtitle != nil ? 1 : 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle(title, isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    customAction?(newValue)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.45 : 1.0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle != nil ? 50 : 46)
    }
}

struct SettingsPickerRow<T: Hashable>: View {
    var systemImage: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var selection: T
    let options: [(tag: T, label: String)]
    var pickerWidth: CGFloat? = 160
    var isDisabled: Bool = false
    var onChange: ((T) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var selectedLabel: String {
        options.first(where: { $0.tag == selection })?.label ?? ""
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: subtitle != nil ? 1 : 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Menu {
                ForEach(options, id: \.tag) { opt in
                    Button {
                        selection = opt.tag
                        onChange?(opt.tag)
                    } label: {
                        HStack {
                            Text(opt.label)
                            if opt.tag == selection {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.88) : Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if pickerWidth != nil {
                        Spacer(minLength: 4)
                    }

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : Color(nsColor: .secondaryLabelColor))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: pickerWidth)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(isHovered ? 0.12 : 0.06)
                                : Color.black.opacity(isHovered ? 0.08 : 0.04)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.45 : 1.0)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle != nil ? 50 : 46)
    }
}

struct SettingsSegmentedRow<T: Hashable>: View {
    var systemImage: String? = nil
    let title: String
    var subtitle: String? = nil
    @Binding var selection: T
    let options: [(tag: T, label: String)]
    var pickerWidth: CGFloat = 210
    var isDisabled: Bool = false
    var onChange: ((T) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: subtitle != nil ? 1 : 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }
            }

            Spacer()

            HStack(spacing: 2) {
                ForEach(options, id: \.tag) { opt in
                    let isSelected = selection == opt.tag
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                            selection = opt.tag
                            onChange?(opt.tag)
                        }
                    } label: {
                        Text(opt.label)
                            .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(
                                isSelected
                                    ? (colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                                    : (colorScheme == .dark ? .white.opacity(0.55) : Color(nsColor: .secondaryLabelColor))
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4.5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isSelected ? (colorScheme == .dark ? Color.white.opacity(0.14) : Color.white) : Color.clear)
                                    .shadow(color: isSelected && colorScheme == .light ? Color.black.opacity(0.08) : Color.clear, radius: 1.5, y: 0.5)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2.5)
            .frame(width: pickerWidth)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.45 : 1.0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle != nil ? 50 : 48)
    }
}

struct SettingsButtonRow: View {
    var systemImage: String? = nil
    let title: String
    var subtitle: String? = nil
    let buttonTitle: String
    var buttonWidth: CGFloat = 150
    var isDestructive: Bool = false
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: subtitle != nil ? 1 : 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }
            }

            Spacer()

            LotusSettingsButton(
                title: buttonTitle,
                isDestructive: isDestructive,
                action: action
            )
        }
        .padding(.horizontal, 16)
        .frame(minHeight: subtitle != nil ? 50 : 48)
    }
}

// MARK: - Lotus Settings Button & Style (Unified Size & Padding matching Bookmarks Header)

struct LotusSettingsButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        LotusSettingsButtonBody(configuration: configuration, isDestructive: isDestructive, isEnabled: isEnabled)
    }
}

extension ButtonStyle where Self == LotusSettingsButtonStyle {
    static var lotusSettings: LotusSettingsButtonStyle { LotusSettingsButtonStyle() }
    static func lotusSettings(destructive: Bool) -> LotusSettingsButtonStyle {
        LotusSettingsButtonStyle(isDestructive: destructive)
    }
}

private struct LotusSettingsButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let isDestructive: Bool
    let isEnabled: Bool

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        if isDestructive {
            return Color(nsColor: .systemRed)
        }
        if isHovered {
            return colorScheme == .dark ? .white : Color(nsColor: .labelColor)
        }
        return colorScheme == .dark ? .white.opacity(0.88) : Color(nsColor: .labelColor)
    }

    private var backgroundFill: Color {
        if isDestructive {
            return Color(nsColor: .systemRed).opacity(colorScheme == .dark ? (isHovered ? 0.20 : 0.12) : (isHovered ? 0.15 : 0.08))
        }
        return colorScheme == .dark
            ? Color.white.opacity(configuration.isPressed ? 0.16 : (isHovered ? 0.12 : 0.06))
            : Color.black.opacity(configuration.isPressed ? 0.12 : (isHovered ? 0.08 : 0.04))
    }

    private var strokeColor: Color {
        if isDestructive {
            return Color(nsColor: .systemRed).opacity(0.20)
        }
        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    var body: some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1.0 : 0.40)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct LotusSettingsButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
            }
        }
        .buttonStyle(LotusSettingsButtonStyle(isDestructive: isDestructive))
        .disabled(isDisabled)
    }
}

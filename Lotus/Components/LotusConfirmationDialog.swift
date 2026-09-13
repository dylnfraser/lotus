//
//  LotusConfirmationDialog.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI
import AppKit

/// Preset styles for confirmation dialog header icon badges.
enum LotusDialogIconStyle {
    case destructive(systemImage: String = "trash.fill")
    case warning(systemImage: String = "exclamationmark.triangle.fill")
    case accent(systemImage: String, color: Color = .accentColor)
    case custom(gradient: LinearGradient, systemImage: String)

    var systemImage: String {
        switch self {
        case .destructive(let img): return img
        case .warning(let img): return img
        case .accent(let img, _): return img
        case .custom(_, let img): return img
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .destructive:
            return LinearGradient(
                colors: [
                    Color(nsColor: .systemRed).opacity(0.9),
                    Color(nsColor: .systemRed)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .warning:
            return LinearGradient(
                colors: [
                    Color(nsColor: .systemOrange).opacity(0.9),
                    Color(nsColor: .systemOrange)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .accent(_, let color):
            return LinearGradient(
                colors: [color.opacity(0.85), color],
                startPoint: .top,
                endPoint: .bottom
            )
        case .custom(let gradient, _):
            return gradient
        }
    }
}

/// A unified, Dia-styled confirmation modal dialog component.
struct LotusConfirmationDialog<Content: View, SecondaryActions: View, Actions: View>: View {
    let iconStyle: LotusDialogIconStyle?
    let title: String
    let subtitle: String?
    let cardWidth: CGFloat
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let secondaryActions: () -> SecondaryActions
    @ViewBuilder let actions: () -> Actions

    @Environment(\.colorScheme) private var colorScheme

    init(
        iconStyle: LotusDialogIconStyle? = nil,
        title: String,
        subtitle: String? = nil,
        cardWidth: CGFloat = 430,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder secondaryActions: @escaping () -> SecondaryActions,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.iconStyle = iconStyle
        self.title = title
        self.subtitle = subtitle
        self.cardWidth = cardWidth
        self.onCancel = onCancel
        self.content = content
        self.secondaryActions = secondaryActions
        self.actions = actions
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.25)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    onCancel()
                }

            // Modal Card
            VStack(alignment: .leading, spacing: 0) {
                // Header Icon Badge
                if let icon = iconStyle {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                            .fill(icon.gradient)
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                    .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 0.75)
                            )
                            .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1.5)

                        Image(systemName: icon.systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 14)
                }

                // Title
                Text(title)
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                    .lineLimit(2)
                    .padding(.bottom, 8)

                // Subtitle
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(nsColor: .secondaryLabelColor))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 22)
                }

                // Custom Content Slot
                content()

                // Actions Row
                HStack(spacing: 10) {
                    secondaryActions()

                    Spacer(minLength: 12)

                    actions()
                }
                .padding(.top, (subtitle == nil || subtitle?.isEmpty == true) ? 14 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(width: cardWidth)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.106, green: 0.106, blue: 0.114) : Color(red: 0.98, green: 0.98, blue: 0.99))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.48 : 0.16), radius: 28, x: 0, y: 12)
            .offset(y: -30)
            .transition(.lotusPopupSlideDown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
    }
}

// MARK: - Popup Slide-Down Transition

extension AnyTransition {
    /// The standard Lotus popup slide-down transition: drops down fast from above with opacity fade.
    static var lotusPopupSlideDown: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -50).combined(with: .opacity),
            removal: .offset(y: -30).combined(with: .opacity)
        )
    }
}

// MARK: - Generic Lotus Modal Dialog Container

/// A generic modal dialog container featuring the standard darkened backdrop and Lotus slide-down popup animation.
struct LotusModalDialog<Content: View>: View {
    let onCancel: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(colorScheme == .dark ? 0.45 : 0.25)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    onCancel()
                }

            content()
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.48 : 0.16), radius: 28, x: 0, y: 12)
                .offset(y: -30)
                .transition(.lotusPopupSlideDown)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
    }
}

extension LotusConfirmationDialog where SecondaryActions == EmptyView {
    init(
        iconStyle: LotusDialogIconStyle? = nil,
        title: String,
        subtitle: String? = nil,
        cardWidth: CGFloat = 430,
        onCancel: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.init(
            iconStyle: iconStyle,
            title: title,
            subtitle: subtitle,
            cardWidth: cardWidth,
            onCancel: onCancel,
            content: content,
            secondaryActions: { EmptyView() },
            actions: actions
        )
    }
}

// MARK: - Dia-Styled Action Buttons

/// Standard Dia-styled Cancel button with inline ESC keycap badge and keyboard shortcut.
struct LotusDialogCancelButton: View {
    var title: String = "Cancel"
    var showsKeycap: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.white.opacity(isEnabled ? 0.92 : 0.45)
                            : Color(nsColor: .labelColor).opacity(isEnabled ? 1.0 : 0.45)
                    )

                if showsKeycap {
                    Text("ESC")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(
                            colorScheme == .dark
                                ? Color.white.opacity(isEnabled ? 0.55 : 0.30)
                                : Color.black.opacity(isEnabled ? 0.42 : 0.25)
                        )
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? (isHovered && isEnabled ? Color.white.opacity(0.16) : Color.white.opacity(0.11))
                            : (isHovered && isEnabled ? Color.black.opacity(0.09) : Color.black.opacity(0.05))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .onHover { hovering in
            if isEnabled {
                isHovered = hovering
            }
        }
    }
}

/// Standard Dia-styled Secondary / Neutral button (e.g. "Always quit", "Keep Tabs").
struct LotusDialogSecondaryButton: View {
    let title: String
    var shortcutText: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.white.opacity(isEnabled ? 0.92 : 0.45)
                            : Color(nsColor: .labelColor).opacity(isEnabled ? 1.0 : 0.45)
                    )

                if let shortcut = shortcutText {
                    Text(shortcut)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundColor(
                            colorScheme == .dark
                                ? Color.white.opacity(isEnabled ? 0.55 : 0.30)
                                : Color.black.opacity(isEnabled ? 0.42 : 0.25)
                        )
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        colorScheme == .dark
                            ? (isHovered && isEnabled ? Color.white.opacity(0.16) : Color.white.opacity(0.11))
                            : (isHovered && isEnabled ? Color.black.opacity(0.09) : Color.black.opacity(0.05))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if isEnabled {
                isHovered = hovering
            }
        }
    }
}

/// Standard Dia-styled Confirm / Destructive action button with inline return keycap and keyboard shortcut.
struct LotusDialogActionButton: View {
    let title: String
    var isDestructive: Bool = true
    var systemIcon: String? = nil
    var showsReturnKeycap: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var buttonColor: Color {
        if !isEnabled {
            return isDestructive
                ? Color(red: 0.92, green: 0.14, blue: 0.12).opacity(0.40)
                : Color(red: 0.16, green: 0.50, blue: 0.98).opacity(0.40)
        }
        if isDestructive {
            return isHovered ? Color(red: 0.98, green: 0.20, blue: 0.18) : Color(red: 0.92, green: 0.14, blue: 0.12)
        } else {
            return isHovered ? Color(red: 0.22, green: 0.56, blue: 1.0) : Color(red: 0.16, green: 0.50, blue: 0.98)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = systemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                if showsReturnKeycap {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.88)
                }
            }
            .foregroundColor(.white.opacity(isEnabled ? 1.0 : 0.60))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(buttonColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .onHover { hovering in
            if isEnabled {
                isHovered = hovering
            }
        }
    }
}

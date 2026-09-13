//
//  FolderRow.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI

/// Sidebar row for a tab folder: disclosure chevron, folder icon, name
/// (inline-renamable), and a hover close button. Sized to match tab rows so
/// the tabstrip's uniform row-height drag math keeps working.
struct FolderRow: View {
    let folder: TabFolder
    let isRenaming: Bool
    let onToggleCollapse: () -> Void
    let onCommitRename: (String) -> Void
    let onCancelRename: () -> Void
    let onClose: () -> Void

    @State private var draftName: String = ""
    @FocusState private var isNameFocused: Bool
    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.5) : Color(nsColor: .secondaryLabelColor)
    }

    private var hoverFill: Color {
        folder.color.color.opacity(colorScheme == .dark ? 0.20 : 0.40)
    }

    private var restingFill: Color {
        folder.color.color.opacity(colorScheme == .dark ? 0.10 : 0.30)
    }

    private var borderStroke: Color {
        folder.color.color.opacity(colorScheme == .dark ? 0.28 : 0.48)
    }

    private var headerTextColor: Color {
        colorScheme == .dark ? folder.color.color : folder.color.color
    }

    var body: some View {
        // Deliberately NOT a Button: on macOS a Button captures mouse
        // tracking, which starves the tabstrip's DragGesture and breaks
        // folder dragging. Tap handling mirrors TabButton's onTapGesture.
        HStack(spacing: 8) {
            let iconName = folder.icon ?? (folder.isArchive ? (folder.isCollapsed ? "archivebox.fill" : "archivebox") : (folder.isCollapsed ? "folder.fill" : "folder"))
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(folder.color.color)
                .frame(width: 16, height: 16)
                // No animation suppression here: it made the icon snap
                // while the row itself animated, lagging the springs.
                .contentTransition(.identity)

            if isRenaming {
                TextField("Folder Name", text: $draftName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(headerTextColor)
                    .textFieldStyle(.plain)
                    .focused($isNameFocused)
                    .onSubmit {
                        onCommitRename(draftName)
                    }
                    .onExitCommand {
                        onCancelRename()
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(headerTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)

            // Cross close button (visible on hover, matching TabButton alignment)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(folder.color.color.opacity(0.75))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .opacity(isHovered && !isRenaming ? 1 : 0)
            .allowsHitTesting(isHovered && !isRenaming)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isHovered && !isRenaming ? hoverFill : restingFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(borderStroke, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            guard !isRenaming else { return }
            onToggleCollapse()
        }
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draftName = folder.name
                isNameFocused = true
                DispatchQueue.main.async {
                    isNameFocused = true
                }
            }
        }
    }
}

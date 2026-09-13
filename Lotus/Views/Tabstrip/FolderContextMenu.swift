//
//  FolderContextMenu.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import AppKit

/// Header with folder name, tab count, and color swatches hosted inside a native macOS context menu.
struct FolderContextMenuHeaderView: View {
    let folder: TabFolder
    let tabCount: Int
    let onSelectColor: (FolderColor) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                let iconName = folder.icon ?? (folder.isArchive ? "archivebox.fill" : "folder.fill")
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(folder.color.color)

                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text("\(tabCount) \(tabCount == 1 ? "tab" : "tabs")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 7)

            FolderColorSwatchPicker(folder: folder, onSelectColor: onSelectColor)
        }
        .focusable(false)
        .focusEffectDisabled()
    }
}

struct FolderIconPicker: View {
    let folder: TabFolder
    let onSelectIcon: (String?) -> Void

    @State private var hoveredIcon: String? = nil

    private let row1 = Array(Profile.presetIcons.prefix(8))
    private let row2 = Array(Profile.presetIcons.suffix(from: 8))

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            VStack(alignment: .center, spacing: 4) {
                iconRow(icons: row1)
                iconRow(icons: row2)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if folder.icon != nil {
                Button {
                    onSelectIcon(nil)
                } label: {
                    Text("Reset to Default")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .center)
        .focusable(false)
        .focusEffectDisabled()
    }

    @ViewBuilder
    private func iconRow(icons: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(icons, id: \.self) { icon in
                let isSelected = folder.icon == icon
                let isHovered = hoveredIcon == icon

                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(folder.color.color.opacity(0.20))
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(folder.color.color, lineWidth: 1.25)
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.primary.opacity(0.08))
                    }

                    Image(systemName: icon)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? folder.color.color : (isHovered ? .primary : .secondary))
                }
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelected {
                        onSelectIcon(nil)
                    } else {
                        onSelectIcon(icon)
                    }
                }
                .onHover { hovering in
                    hoveredIcon = hovering ? icon : (hoveredIcon == icon ? nil : hoveredIcon)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct FolderColorSwatchPicker: View {
    let folder: TabFolder
    let onSelectColor: (FolderColor) -> Void

    @State private var hoveredColor: FolderColor? = nil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(FolderColor.allCases) { color in
                let isSelected = color == folder.color
                let isHovered = color == hoveredColor

                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(color.color, lineWidth: 1.75)
                            .frame(width: 20, height: 20)

                        Circle()
                            .fill(color.color)
                            .frame(width: 13, height: 13)
                    } else {
                        if isHovered {
                            Circle()
                                .stroke(color.color.opacity(0.45), lineWidth: 1.25)
                                .frame(width: 20, height: 20)
                        }

                        Circle()
                            .fill(color.color)
                            .frame(width: 15, height: 15)
                    }
                }
                .frame(width: 20, height: 20)
                .contentShape(Circle())
                .onTapGesture {
                    onSelectColor(color)
                }
                .onHover { hovering in
                    hoveredColor = hovering ? color : (hoveredColor == color ? nil : hoveredColor)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .focusable(false)
        .focusEffectDisabled()
    }
}

/// Custom hosting view that suppresses focus rings inside menus.
final class MenuPaletteHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { false }
    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }
}

/// AppKit hosting view for native folder context menus with embedded color swatches.
struct FolderContextMenuHost: NSViewRepresentable {
    let folder: TabFolder
    let browserState: BrowserState
    let onRename: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> FolderContextMenuNSView {
        let view = FolderContextMenuNSView()
        view.folder = folder
        view.browserState = browserState
        view.onRename = onRename
        view.onClose = onClose
        view.onDelete = onDelete
        return view
    }

    func updateNSView(_ nsView: FolderContextMenuNSView, context: Context) {
        nsView.folder = folder
        nsView.browserState = browserState
        nsView.onRename = onRename
        nsView.onClose = onClose
        nsView.onDelete = onDelete
    }
}

final class FolderContextMenuNSView: NSView {
    var folder: TabFolder?
    var browserState: BrowserState?
    var onRename: (() -> Void)?
    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Only intercept right-clicks so left clicks (collapse/expand) and
        // DragGesture (reordering) pass straight through to SwiftUI.
        guard let currentEvent = NSApp.currentEvent,
              currentEvent.type == .rightMouseDown || currentEvent.type == .rightMouseUp else {
            return nil
        }
        return super.hitTest(point)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let folder = folder, let browserState = browserState else { return nil }
        return buildMenu(folder: folder, browserState: browserState)
    }

    private func buildMenu(folder: TabFolder, browserState: BrowserState) -> NSMenu {
        let menu = NSMenu()

        // 1. Folder title, tab count, and color swatches
        let tabCount = browserState.tabs.filter { $0.folderId == folder.id }.count
        let headerView = FolderContextMenuHeaderView(
            folder: folder,
            tabCount: tabCount,
            onSelectColor: { [weak menu] newColor in
                browserState.setFolderColor(id: folder.id, to: newColor)
                menu?.cancelTracking()
            }
        )
        let hostingView = MenuPaletteHostingView(rootView: headerView)
        hostingView.focusRingType = .none
        let fitting = hostingView.fittingSize
        hostingView.frame = NSRect(x: 0, y: 0, width: fitting.width, height: fitting.height)

        let headerItem = NSMenuItem()
        headerItem.view = hostingView
        menu.addItem(headerItem)

        // 2. Rename…
        let renameItem = NSMenuItem(title: "Rename…", action: #selector(handleRename), keyEquivalent: "")
        renameItem.target = self
        menu.addItem(renameItem)

        // 3. Change Icon Submenu
        let iconSubmenu = NSMenu()
        let iconPickerView = FolderIconPicker(
            folder: folder,
            onSelectIcon: { [weak menu] newIcon in
                browserState.setFolderIcon(id: folder.id, to: newIcon)
                menu?.cancelTracking()
            }
        )
        let iconHostingView = MenuPaletteHostingView(rootView: iconPickerView)
        iconHostingView.focusRingType = .none
        let iconFitting = iconHostingView.fittingSize
        iconHostingView.frame = NSRect(x: 0, y: 0, width: max(iconFitting.width, 216), height: iconFitting.height)

        let iconPickerItem = NSMenuItem()
        iconPickerItem.view = iconHostingView
        iconSubmenu.addItem(iconPickerItem)

        let iconMenuItem = NSMenuItem(title: "Change Icon", action: nil, keyEquivalent: "")
        iconMenuItem.submenu = iconSubmenu
        menu.addItem(iconMenuItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Close All Tabs in Folder
        let closeItem = NSMenuItem(title: "Close All Tabs in Folder", action: #selector(handleClose), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        // 4. Delete Folder
        let deleteItem = NSMenuItem(title: "Ungroup Folder", action: #selector(handleDelete), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(deleteItem)

        // 5. Move to Profile
        if browserState.profiles.count > 1 {
            let currentProfileId = folder.profileId ?? browserState.defaultProfileId
            let otherProfiles = browserState.profiles.filter { $0.id != currentProfileId }
            if !otherProfiles.isEmpty {
                menu.addItem(NSMenuItem.separator())
                let moveMenu = NSMenu()
                for p in otherProfiles {
                    let pItem = NSMenuItem(title: p.name, action: #selector(handleMoveToProfile(_:)), keyEquivalent: "")
                    pItem.target = self
                    pItem.representedObject = p.id
                    moveMenu.addItem(pItem)
                }
                let moveItem = NSMenuItem(title: "Move Folder to Profile", action: nil, keyEquivalent: "")
                moveItem.submenu = moveMenu
                menu.addItem(moveItem)
            }
        }

        return menu
    }

    @objc private func handleMoveToProfile(_ sender: NSMenuItem) {
        guard let targetProfileId = sender.representedObject as? UUID, let folder = folder, let browserState = browserState else { return }
        browserState.moveFolder(folder.id, toProfile: targetProfileId)
    }

    @objc private func handleRename() {
        onRename?()
    }

    @objc private func handleClose() {
        onClose?()
    }

    @objc private func handleDelete() {
        onDelete?()
    }
}

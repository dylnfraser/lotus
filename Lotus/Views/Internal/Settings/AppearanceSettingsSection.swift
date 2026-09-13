//
//  AppearanceSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/22/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppearanceSettingsSection: View {
    var browserState: BrowserState? = nil

    @AppStorage("lotus.browser.appearance") private var appearanceMode: String = "system"
    @AppStorage("lotus.browser.titlebarChromeTintingMode") private var titlebarChromeTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.sidebarTabTintingMode") private var sidebarTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.pinnedTabTintingMode") private var pinnedTabTintingMode: String = "adaptive"
    @AppStorage("lotus.browser.centerURLPreview") private var centerURLPreview: Bool = false
    @AppStorage("lotus.browser.centerCommandPaletteOverWebview") private var centerCommandPaletteOverWebview: Bool = false
    @AppStorage("lotus.browser.topBarVisibility") private var topBarVisibility: String = "always"
    @AppStorage("lotus.browser.showsBrowserFrame") private var showsBrowserFrame: Bool = true
    @AppStorage("lotus.browser.showsRoundedWebCorners") private var showsRoundedWebCorners: Bool = true
    @AppStorage("lotus.browser.smoothTabSwitchAnimation") private var smoothTabSwitchAnimation: Bool = true
    @AppStorage("lotus.browser.toolbarLayout") private var toolbarLayoutRaw: String = ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)

    var body: some View {
        VStack(spacing: 16) {
            SettingsSectionCard(title: "Theme & Tinting") {
                SettingsSegmentedRow(
                    systemImage: "circle.lefthalf.filled",
                    title: "Theme",
                    selection: $appearanceMode,
                    options: [("system", "System"), ("light", "Light"), ("dark", "Dark")],
                    pickerWidth: 210
                )
                SettingsDivider()
                SettingsPickerRow(
                    systemImage: "menubar.rectangle",
                    title: "Toolbar chrome tinting",
                    subtitle: "Tints top toolbar and container with site's dominant accent",
                    selection: $titlebarChromeTintingMode,
                    options: [("adaptive", "Adaptive"), ("neutral", "Neutral"), ("systemAccent", "Accent")],
                    pickerWidth: 140
                )
                SettingsDivider()
                SettingsPickerRow(
                    systemImage: "sidebar.left",
                    title: "Sidebar tab tinting",
                    subtitle: "Tints active tab selection with site's dominant accent",
                    selection: $sidebarTabTintingMode,
                    options: [("adaptive", "Adaptive"), ("neutral", "Neutral"), ("systemAccent", "Accent")],
                    pickerWidth: 140
                )
                SettingsDivider()
                SettingsPickerRow(
                    systemImage: "pin",
                    title: "Pinned tab tinting",
                    subtitle: "Tints pinned tab cards with vibrant site gradients",
                    selection: $pinnedTabTintingMode,
                    options: [("adaptive", "Adaptive"), ("neutral", "Neutral"), ("systemAccent", "Accent")],
                    pickerWidth: 140
                )
            }

            SettingsSectionCard(title: "Window & Layout") {
                SettingsPickerRow(
                    systemImage: "menubar.rectangle",
                    title: "Toolbar",
                    selection: $topBarVisibility,
                    options: [("always", "Always"), ("hover", "Hover"), ("never", "Never")],
                    pickerWidth: 130
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "text.aligncenter",
                    title: "Center address bar preview",
                    subtitle: "Centers text in inactive URL address bar",
                    isOn: $centerURLPreview
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "command",
                    title: "Center Command Palette",
                    subtitle: "Centers the palette in the window instead of top-aligning",
                    isOn: $centerCommandPaletteOverWebview
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "rectangle.inset.filled",
                    title: "Browser frame",
                    isOn: $showsBrowserFrame
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "rectangle",
                    title: "Rounded web corners",
                    isOn: $showsRoundedWebCorners
                )
                SettingsDivider()
                SettingsToggleRow(
                    systemImage: "slider.horizontal.below.rectangle",
                    title: "Smooth tab switch animation",
                    subtitle: "Animate tab selection highlights and sliding transitions",
                    isOn: $smoothTabSwitchAnimation
                )
            }

            ToolbarArrangementSettingsCard(toolbarLayoutRaw: $toolbarLayoutRaw)
        }
    }
}

// MARK: - Toolbar Arrangement Settings Card

private struct ToolbarArrangementSettingsCard: View {
    @Binding var toolbarLayoutRaw: String
    @State private var draggedItem: ToolbarItemType? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var items: [ToolbarItemType] {
        ToolbarItemType.parseLayout(from: toolbarLayoutRaw)
    }

    private var availableItems: [ToolbarItemType] {
        ToolbarItemType.availableItems(for: items)
    }

    private var isDefaultOrder: Bool {
        toolbarLayoutRaw == ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)
    }

    private func swapItems(at index: Int, with otherIndex: Int) {
        guard index != otherIndex, index >= 0, index < items.count, otherIndex >= 0, otherIndex < items.count else { return }
        var updated = items
        updated.swapAt(index, otherIndex)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func reorderItem(_ sourceItem: ToolbarItemType, relativeTo targetItem: ToolbarItemType, position: DropPosition) {
        guard sourceItem != targetItem else { return }
        var updated = items
        if let fromIndex = updated.firstIndex(of: sourceItem) {
            updated.remove(at: fromIndex)
        }
        guard let targetIndex = updated.firstIndex(of: targetItem) else { return }
        let insertIndex = position == .above ? targetIndex : targetIndex + 1
        let clampedIndex = max(0, min(insertIndex, updated.count))
        updated.insert(sourceItem, at: clampedIndex)
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func addItem(_ item: ToolbarItemType) {
        var updated = items
        if !updated.contains(item) {
            updated.append(item)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
            }
        }
    }

    private func removeItem(_ item: ToolbarItemType) {
        var updated = items
        updated.removeAll { $0 == item }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(updated)
        }
    }

    private func resetToDefault() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            toolbarLayoutRaw = ToolbarItemType.serializeLayout(ToolbarItemType.defaultOrder)
        }
    }

    var body: some View {
        SettingsSectionCard(
            title: "Toolbar Layout",
//            footer: "Drag items to reorder them on the top toolbar or remove them from view."
        ) {
            // Header summary and Reset action
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toolbar items & arrangement")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text("Drag to reorder, use arrows, or remove items from the toolbar")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer()

                LotusSettingsButton(
                    title: "Reset Default",
                    systemImage: "arrow.counterclockwise",
                    isDisabled: isDefaultOrder
                ) {
                    resetToDefault()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            SettingsDivider()

            // Active Toolbar Items List
            if items.isEmpty {
                HStack {
                    Spacer()
                    Text("No items on toolbar. Drag items here or click Add below.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.4) : .secondary)
                        .padding(.vertical, 16)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onDrop(of: [UTType.text, UTType.plainText, UTType.utf8PlainText], delegate: EmptyToolbarDropDelegate(
                    draggedItem: $draggedItem,
                    onAdd: addItem
                ))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ToolbarItemReorderRow(
                            item: item,
                            index: index,
                            totalCount: items.count,
                            draggedItem: $draggedItem,
                            onMoveUp: {
                                swapItems(at: index, with: index - 1)
                            },
                            onMoveDown: {
                                swapItems(at: index, with: index + 1)
                            },
                            onRemove: {
                                removeItem(item)
                            },
                            onDropReorder: { sourceItem, position in
                                reorderItem(sourceItem, relativeTo: item, position: position)
                            }
                        )

                        if index < items.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }

            // Available Items Section (Always Visible)
            SettingsDivider()

            AvailableItemsSectionView(
                availableItems: availableItems,
                draggedItem: $draggedItem,
                onAdd: addItem,
                onRemove: removeItem
            )
        }
    }
}

// MARK: - Available Items Section View

private struct AvailableItemsSectionView: View {
    let availableItems: [ToolbarItemType]
    @Binding var draggedItem: ToolbarItemType?
    let onAdd: (ToolbarItemType) -> Void
    let onRemove: (ToolbarItemType) -> Void

    @State private var isTargeted: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var availableItemsFill: Color {
        if isTargeted {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
        return colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }

    private var availableItemsStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
    }

    private var emptyStateIconColor: Color {
        if isTargeted {
            return colorScheme == .dark ? .white : .primary
        }
        return colorScheme == .dark ? .white.opacity(0.4) : .secondary
    }

    @ViewBuilder
    private var emptyStateView: some View {
        HStack {
            Spacer()
            VStack(spacing: 5) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(emptyStateIconColor)

                Text("All items are in your toolbar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.75) : .primary)

                Text("Drag items here from above to remove them")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary)
            }
            .padding(.vertical, 16)
            Spacer()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Available Items")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isTargeted ? (colorScheme == .dark ? .white : .primary) : (colorScheme == .dark ? .white.opacity(0.5) : .secondary))
                    .textCase(.uppercase)

                Spacer()

                Text(availableItems.isEmpty ? "Drag items here to remove" : "Click + or drag to toolbar")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 2)

            Group {
                if availableItems.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(availableItems.enumerated()), id: \.element.id) { index, item in
                            ToolbarAvailableItemRow(
                                item: item,
                                draggedItem: $draggedItem,
                                onAdd: {
                                    onAdd(item)
                                }
                            )

                            if index < availableItems.count - 1 {
                                SettingsDivider(leadingInset: 10)
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(availableItemsFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(availableItemsStroke, lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isTargeted)
        .onDrop(of: [UTType.text, UTType.plainText, UTType.utf8PlainText], delegate: AvailableSectionDropDelegate(
            draggedItem: $draggedItem,
            isTargeted: $isTargeted,
            onRemove: onRemove
        ))
    }
}

// MARK: - Toolbar Drag Store

private enum ToolbarDragStore {
    static var currentItem: ToolbarItemType? = nil
}

// MARK: - Drop Position Enum

private enum DropPosition {
    case above
    case below
}

// MARK: - Toolbar Item Reorder Row

private struct ToolbarItemReorderRow: View {
    let item: ToolbarItemType
    let index: Int
    let totalCount: Int
    @Binding var draggedItem: ToolbarItemType?
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onDropReorder: (ToolbarItemType, DropPosition) -> Void

    @State private var isTargeted: Bool = false
    @State private var dropPosition: DropPosition = .above
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Main draggable content area
            HStack(spacing: 12) {
                // Drag grip indicator
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.3) : .secondary.opacity(0.35))
                    .frame(width: 14)

                // Icon square badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))

                    Image(systemName: item.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : Color(nsColor: .labelColor))
                }
                .frame(width: 28, height: 28)

                // Title and description
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.92) : .primary)

                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.45) : .secondary)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())

            // Reordering buttons (Move Up / Move Down)
            HStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .opacity(index == 0 ? 0.25 : 0.75)
                .help("Move Up")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(index == totalCount - 1)
                .opacity(index == totalCount - 1 ? 0.25 : 0.75)
                .help("Move Down")
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            )

            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.5) : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove from Toolbar")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
            (isTargeted && (draggedItem ?? ToolbarDragStore.currentItem) != item)
                ? (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                : Color.white.opacity(0.0001)
        )
        .contentShape(Rectangle())
        .overlay(
            Group {
                if isTargeted && (draggedItem ?? ToolbarDragStore.currentItem) != item {
                    VStack {
                        if dropPosition == .below {
                            Spacer()
                        }
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.85) : Color.primary.opacity(0.75))
                            .frame(height: 2)
                            .padding(.horizontal, 10)
                        if dropPosition == .above {
                            Spacer()
                        }
                    }
                }
            }
        )
        .opacity((draggedItem ?? ToolbarDragStore.currentItem) == item ? 0.35 : 1.0)
        .onDrag {
            draggedItem = item
            ToolbarDragStore.currentItem = item
            let provider = NSItemProvider(object: NSString(string: item.rawValue))
            provider.suggestedName = item.displayName
            return provider
        }
        .onDrop(of: [UTType.text, UTType.plainText, UTType.utf8PlainText], delegate: ToolbarDropDelegate(
            targetItem: item,
            draggedItem: $draggedItem,
            isTargeted: $isTargeted,
            dropPosition: $dropPosition,
            onDropAction: onDropReorder
        ))
    }
}

// MARK: - Toolbar Available Item Row

private struct ToolbarAvailableItemRow: View {
    let item: ToolbarItemType
    @Binding var draggedItem: ToolbarItemType?
    let onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Main draggable content area
            HStack(spacing: 12) {
                // Drag grip indicator
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.25) : .secondary.opacity(0.3))
                    .frame(width: 14)

                // Icon square badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))

                    Image(systemName: item.iconName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
                }
                .frame(width: 28, height: 28)

                // Title and description
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.75) : .primary.opacity(0.85))

                    Text(item.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.35) : .secondary.opacity(0.8))
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())

            // Add Button
            LotusSettingsButton(
                title: "Add",
                systemImage: "plus"
            ) {
                onAdd()
            }
            .help("Add \(item.displayName) to Toolbar")
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(Color.white.opacity(0.0001))
        .contentShape(Rectangle())
        .opacity((draggedItem ?? ToolbarDragStore.currentItem) == item ? 0.35 : 1.0)
        .onDrag {
            draggedItem = item
            ToolbarDragStore.currentItem = item
            let provider = NSItemProvider(object: NSString(string: item.rawValue))
            provider.suggestedName = item.displayName
            return provider
        }
    }
}

// MARK: - Drop Delegates

private struct ToolbarDropDelegate: DropDelegate {
    let targetItem: ToolbarItemType
    @Binding var draggedItem: ToolbarItemType?
    @Binding var isTargeted: Bool
    @Binding var dropPosition: DropPosition
    let onDropAction: (ToolbarItemType, DropPosition) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItem != nil || ToolbarDragStore.currentItem != nil || info.hasItemsConforming(to: [UTType.text, UTType.plainText, UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        updatePosition(info: info)
        isTargeted = true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePosition(info: info)
        return DropProposal(operation: .move)
    }

    private func updatePosition(info: DropInfo) {
        let isAbove = info.location.y < 24
        let newPos: DropPosition = isAbove ? .above : .below
        if dropPosition != newPos {
            dropPosition = newPos
        }
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let isAbove = info.location.y < 24
        let pos: DropPosition = isAbove ? .above : .below

        let source = draggedItem ?? ToolbarDragStore.currentItem
        draggedItem = nil
        ToolbarDragStore.currentItem = nil

        if let source {
            onDropAction(source, pos)
            return true
        }

        let types = [UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.text.identifier]
        for type in types {
            if let itemProvider = info.itemProviders(for: [UTType(type) ?? .text]).first {
                itemProvider.loadItem(forTypeIdentifier: type, options: nil) { data, _ in
                    if let stringData = data as? Data, let raw = String(data: stringData, encoding: .utf8),
                       let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onDropAction(dropped, pos)
                        }
                    } else if let raw = data as? String, let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onDropAction(dropped, pos)
                        }
                    }
                }
                return true
            }
        }

        return false
    }
}

private struct EmptyToolbarDropDelegate: DropDelegate {
    @Binding var draggedItem: ToolbarItemType?
    let onAdd: (ToolbarItemType) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItem != nil || ToolbarDragStore.currentItem != nil || info.hasItemsConforming(to: [UTType.text, UTType.plainText, UTType.utf8PlainText])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let source = draggedItem ?? ToolbarDragStore.currentItem
        draggedItem = nil
        ToolbarDragStore.currentItem = nil

        if let source {
            onAdd(source)
            return true
        }

        let types = [UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.text.identifier]
        for type in types {
            if let itemProvider = info.itemProviders(for: [UTType(type) ?? .text]).first {
                itemProvider.loadItem(forTypeIdentifier: type, options: nil) { data, _ in
                    if let stringData = data as? Data, let raw = String(data: stringData, encoding: .utf8),
                       let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onAdd(dropped)
                        }
                    } else if let raw = data as? String, let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onAdd(dropped)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

private struct AvailableSectionDropDelegate: DropDelegate {
    @Binding var draggedItem: ToolbarItemType?
    @Binding var isTargeted: Bool
    let onRemove: (ToolbarItemType) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedItem != nil || ToolbarDragStore.currentItem != nil || info.hasItemsConforming(to: [UTType.text, UTType.plainText, UTType.utf8PlainText])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let source = draggedItem ?? ToolbarDragStore.currentItem
        draggedItem = nil
        ToolbarDragStore.currentItem = nil

        if let source {
            onRemove(source)
            return true
        }

        let types = [UTType.utf8PlainText.identifier, UTType.plainText.identifier, UTType.text.identifier]
        for type in types {
            if let itemProvider = info.itemProviders(for: [UTType(type) ?? .text]).first {
                itemProvider.loadItem(forTypeIdentifier: type, options: nil) { data, _ in
                    if let stringData = data as? Data, let raw = String(data: stringData, encoding: .utf8),
                       let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onRemove(dropped)
                        }
                    } else if let raw = data as? String, let dropped = ToolbarItemType(rawValue: raw) {
                        DispatchQueue.main.async {
                            onRemove(dropped)
                        }
                    }
                }
                return true
            }
        }

        return false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

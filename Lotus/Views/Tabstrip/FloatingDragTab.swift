//
//  FloatingDragTab.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/21/26.
//

import SwiftUI

struct FloatingDragTab: View {
    let tab: TabItem
    var splitPair: (TabItem, TabItem)? = nil
    let isPinnedPreview: Bool
    let pinnedCardWidth: CGFloat
    let sidebarWidth: CGFloat
    let isThemeLight: Bool
    let activeTabBackgroundColor: Color
    var profileColor: Color = .blue
    /// When set, the ghost renders a folder header instead of a tab.
    var folder: TabFolder? = nil
    var folderTabCount: Int = 0
    var previewCount: Int = 1

    var body: some View {
        Group {
            if let folder {
                // The ghost always previews the folder closed — it re-expands
                // in place on drop.
                let ghostFolder: TabFolder = {
                    var ghost = folder
                    ghost.isCollapsed = true
                    return ghost
                }()
                FolderRow(
                    folder: ghostFolder,
                    isRenaming: false,
                    onToggleCollapse: {},
                    onCommitRename: { _ in },
                    onCancelRename: {},
                    onClose: {}
                )
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .frame(width: max(60, sidebarWidth - 16))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else if isPinnedPreview {
                PinnedTabButton(
                    tab: tab,
                    isSelected: true,
                    profileAccentColor: profileColor,
                    onSelect: {}
                )
                .frame(width: pinnedCardWidth)
            } else if let (tab1, tab2) = splitPair {
                SplitTabRow(
                    tab1: tab1,
                    tab2: tab2,
                    selectedTabId: tab.id,
                    currentTabIds: [tab1.id, tab2.id],
                    sidebarWidth: sidebarWidth,
                    isThemeLight: isThemeLight,
                    activeTabBackgroundColor: activeTabBackgroundColor,
                    namespace: nil,
                    activeDrag: nil,
                    onSelect: { _ in },
                    onClose: { _ in },
                    onDragChanged: { _, _ in },
                    onDragEnded: { _ in },
                    contextMenuBuilder: { _ in AnyView(EmptyView()) }
                )
                .frame(width: max(60, sidebarWidth - 16))
            } else {
                TabButton(
                    tab: tab,
                    isSelected: true,
                    isDragging: true,
                    isThemeLight: isThemeLight,
                    activeTabBackgroundColor: activeTabBackgroundColor,
                    sidebarWidth: sidebarWidth,
                    onSelect: {},
                    onClose: {}
                )
                .frame(width: max(60, sidebarWidth - 16))
            }
        }
        .background {
            if folder == nil && previewCount > 1 {
                ZStack {
                    RoundedRectangle(cornerRadius: isPinnedPreview ? 13 : 9, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
                        .offset(x: 8, y: 8)
                    if previewCount > 2 {
                        RoundedRectangle(cornerRadius: isPinnedPreview ? 13 : 9, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.86))
                            .offset(x: 4, y: 4)
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if folder == nil && previewCount > 1 {
                Text("\(previewCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isThemeLight ? .black : .white)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 20)
                    .background(Capsule(style: .continuous).fill(activeTabBackgroundColor))
                    .offset(x: 8, y: -8)
            }
        }
        .scaleEffect(isPinnedPreview ? 1.05 : 1.02)
        .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isPinnedPreview)
    }
}

//
//  LotusHeaderActionButton.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct LotusHeaderActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        if isDestructive {
            return Color(nsColor: .systemRed)
        }
        if isHovered {
            return colorScheme == .dark ? .white : Color(nsColor: .labelColor)
        }
        return colorScheme == .dark ? .white.opacity(0.48) : Color(nsColor: .secondaryLabelColor)
    }

    private var hoverFill: Color {
        if isDestructive {
            return Color(nsColor: .systemRed).opacity(colorScheme == .dark ? 0.15 : 0.10)
        }
        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? hoverFill : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

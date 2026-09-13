//
//  ProfileSwitcherView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/25/26.
//

import SwiftUI
import AppKit

struct ProfileSwitcherView: View {
    @ObservedObject var browserState: BrowserState
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered: Bool = false

    private var profile: Profile {
        browserState.currentProfile
    }

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.55) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        Menu {
            // Profile list
            Section("Switch Profile") {
                ForEach(browserState.profiles) { p in
                    Button {
                        browserState.switchProfile(to: p.id)
                    } label: {
                        Label(p.name, systemImage: p.icon)
                    }
                }
            }

            Divider()

            Button {
                browserState.openCreateProfile()
            } label: {
                Label("New Profile…", systemImage: "plus")
            }

            Button {
                browserState.openSettingsPage()
            } label: {
                Label("Manage Profiles…", systemImage: "gearshape")
            }

            if browserState.canDeleteProfile(profile) {
                Divider()
                Button(role: .destructive) {
                    browserState.requestDeleteProfile(profile)
                } label: {
                    Label("Delete Profile…", systemImage: "trash")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: profile.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(foregroundPrimary)

                Text(profile.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(foregroundPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if isHovered {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(foregroundSecondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovered ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06)) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .focusable(false)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

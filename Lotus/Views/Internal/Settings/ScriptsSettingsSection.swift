//
//  ScriptsSettingsSection.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct ScriptsSettingsSection: View {
    @ObservedObject var browserState: BrowserState
    @ObservedObject private var service = UserScriptService.shared
    @State private var isCreating: Bool = false
    @State private var editingScript: UserScript? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var foregroundPrimary: Color {
        colorScheme == .dark ? .white : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? .white.opacity(0.45) : Color(nsColor: .secondaryLabelColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Master toggle card
            SettingsSectionCard(title: "User Scripts & Styles") {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .systemPurple).gradient)
                                .frame(width: 26, height: 26)
                            Image(systemName: "curlybraces")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Enable User Scripts & Styles")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(foregroundPrimary)
                            Text("Inject custom CSS or JavaScript into matching websites")
                                .font(.system(size: 11))
                                .foregroundColor(foregroundSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { service.isEnabled },
                            set: { service.setGlobalEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)

                    if service.isEnabled {
                        ForEach(Array(service.scripts.enumerated()), id: \.element.id) { index, script in
                            SettingsDivider(leadingInset: 54)
                            scriptRow(for: script)
                        }
                    }
                }
            }

            // Add Script card
            SettingsSectionCard(title: "Add Script or Style") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Custom Script or Style")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(foregroundPrimary)
                        Text("Write CSS or JavaScript to run on matching domains")
                            .font(.system(size: 11))
                            .foregroundColor(foregroundSecondary)
                    }
                    Spacer()
                    LotusSettingsButton(
                        title: "New Script…",
                        systemImage: "plus",
                        isDisabled: !service.isEnabled
                    ) {
                        isCreating = true
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
            }
        }
        .sheet(isPresented: $isCreating) {
            UserScriptEditorModalView(
                mode: .create,
                onSave: { script in
                    service.add(script)
                    isCreating = false
                },
                onCancel: {
                    isCreating = false
                }
            )
        }
        .sheet(item: $editingScript) { script in
            UserScriptEditorModalView(
                mode: .edit(script),
                onSave: { updated in
                    service.update(updated)
                    editingScript = nil
                    browserState.reapplyUserScriptsToAllTabs()
                },
                onCancel: {
                    editingScript = nil
                }
            )
        }
    }

    @ViewBuilder
    private func scriptRow(for script: UserScript) -> some View {
        HStack(spacing: 10) {
            // Type icon
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(script.type == .css ? Color(nsColor: .systemPurple).opacity(0.15) : Color(nsColor: .systemOrange).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: script.type == .css ? "paintbrush.fill" : "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(script.type == .css ? Color(nsColor: .systemPurple) : Color(nsColor: .systemOrange))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(script.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(script.isEnabled ? foregroundPrimary : foregroundSecondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(script.domainPattern)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(foregroundSecondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundColor(foregroundSecondary.opacity(0.5))
                        .font(.system(size: 10))
                    Text(script.type.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(foregroundSecondary)
                }
            }

            Spacer()

            // Enable toggle
            Toggle("", isOn: Binding(
                get: { script.isEnabled },
                set: { _ in service.toggle(id: script.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)

            // Edit button
            Button {
                editingScript = script
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(foregroundSecondary)
            }
            .buttonStyle(.plain)

            // Delete button
            Button {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    service.delete(id: script.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(nsColor: .systemRed).opacity(0.70))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
    }
}

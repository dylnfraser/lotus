//
//  CustomBangModalView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct CustomBangModalView: View {
    enum Mode {
        case create
        case edit(CustomBang)

        var title: String {
            switch self {
            case .create: return "Add Custom Bang"
            case .edit: return "Edit Custom Bang"
            }
        }

        var subtitle: String {
            switch self {
            case .create:
                return "Define a search keyword trigger, engine name, query URL schema, color and icon."
            case .edit:
                return "Customize search keyword trigger, engine name, query URL schema, color and icon."
            }
        }

        var actionButtonTitle: String {
            switch self {
            case .create: return "Add Bang"
            case .edit: return "Save Changes"
            }
        }
    }

    enum Field: Hashable {
        case name
        case trigger
        case urlTemplate
    }

    let mode: Mode
    let onSave: (CustomBang) -> Void
    let onDelete: ((CustomBang) -> Void)?
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var trigger: String = ""
    @State private var urlTemplate: String = ""
    @State private var selectedIcon: String = "magnifyingglass"
    @State private var selectedColor: FolderColor = .blue

    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private let presetColors: [FolderColor] = [.grey, .blue, .purple, .pink, .red, .orange, .yellow, .green]

    private var activeColor: Color {
        selectedColor == .grey ? (colorScheme == .dark ? .white : .black) : selectedColor.color
    }

    private var labelColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(nsColor: .labelColor)
    }

    private var subtitleColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color(nsColor: .secondaryLabelColor)
    }

    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.04)
    }

    private var fieldBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    init(
        mode: Mode,
        onSave: @escaping (CustomBang) -> Void,
        onDelete: ((CustomBang) -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _trigger = State(initialValue: "")
            _urlTemplate = State(initialValue: "")
            _selectedIcon = State(initialValue: "magnifyingglass")
            _selectedColor = State(initialValue: .blue)
        case .edit(let bang):
            _name = State(initialValue: bang.name)
            _trigger = State(initialValue: bang.cleanTrigger)
            _urlTemplate = State(initialValue: bang.searchURLTemplate)
            _selectedIcon = State(initialValue: bang.iconName)
            _selectedColor = State(initialValue: bang.color)
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespacesAndNewlines)).isEmpty &&
        !urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(labelColor)

                Text(mode.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(subtitleColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 24)

            // MARK: - Form
            VStack(alignment: .leading, spacing: 20) {

                // Name
                formField(label: "Name", hint: nil) {
                    styledTextField("Name (e.g. GitHub, YouTube, Reddit)", text: $name, field: .name)
                }

                // Trigger Keyword
                formField(label: "Trigger Keyword", hint: {
                    let clean = trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespaces))
                    return Text("Shortcut: !\(clean.isEmpty ? "keyword" : clean)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(activeColor)
                }()) {
                    styledTextField("Trigger keyword without ! (e.g. gh, yt, r)", text: $trigger, field: .trigger)
                }

                // Search URL Schema
                formField(label: "Search URL Schema", hint: nil) {
                    styledTextField("https://example.com/search?q={searchTerms}", text: $urlTemplate, field: .urlTemplate)
                }

                // Icon Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Icon")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(labelColor)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                        ForEach(CustomBang.presetIcons, id: \.self) { iconName in
                            let isSelected = selectedIcon == iconName
                            Button {
                                selectedIcon = iconName
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected
                                            ? activeColor.opacity(colorScheme == .dark ? 0.22 : 0.14)
                                            : fieldBackground
                                        )
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(activeColor, lineWidth: 2)
                                    }
                                    Image(systemName: iconName)
                                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                        .foregroundColor(isSelected
                                            ? activeColor
                                            : (colorScheme == .dark ? Color.white.opacity(0.72) : Color.primary.opacity(0.65))
                                        )
                                }
                                .frame(height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Color Picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Color")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(labelColor)

                    HStack(spacing: 10) {
                        ForEach(presetColors) { color in
                            let isSelected = selectedColor == color
                            let dotColor: Color = (color == .grey
                                ? (colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                                : color.color
                            )
                            Button {
                                selectedColor = color
                            } label: {
                                ZStack {
                                    Circle()
                                        .stroke(dotColor, lineWidth: isSelected ? 2.5 : 0)
                                        .frame(width: 40, height: 40)
                                    Circle()
                                        .fill(dotColor)
                                        .frame(
                                            width: isSelected ? 28 : 34,
                                            height: isSelected ? 28 : 34
                                        )
                                }
                                .frame(width: 42, height: 42)
                                .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isSelected)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)

            // MARK: - Action Buttons
            HStack(spacing: 12) {
                // Cancel
                LotusDialogCancelButton(action: onCancel)

                // Delete (edit mode only)
                if case .edit(let originalBang) = mode, let onDelete = onDelete {
                    LotusDialogActionButton(title: "Delete", isDestructive: true, systemIcon: "trash", showsReturnKeycap: false) {
                        onDelete(originalBang)
                    }
                }

                Spacer()

                // Primary action
                LotusDialogActionButton(title: mode.actionButtonTitle, isDestructive: false, showsReturnKeycap: true) {
                    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanTrigger = trigger.trimmingCharacters(in: CharacterSet(charactersIn: "!").union(.whitespacesAndNewlines))
                    let cleanURL = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty, !cleanTrigger.isEmpty, !cleanURL.isEmpty else { return }

                    var bang: CustomBang
                    if case .edit(let original) = mode {
                        bang = original
                        bang.name = cleanName
                        bang.trigger = cleanTrigger
                        bang.searchURLTemplate = cleanURL
                        bang.iconName = selectedIcon
                        bang.color = selectedColor
                    } else {
                        bang = CustomBang(
                            trigger: cleanTrigger,
                            name: cleanName,
                            searchURLTemplate: cleanURL,
                            iconName: selectedIcon
                        )
                        bang.color = selectedColor
                    }
                    onSave(bang)
                }
                .disabled(!isFormValid)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
            .padding(.top, 10)
        }
        .frame(width: 500)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .name
            }
        }
    }

    // MARK: - View Helpers

    @ViewBuilder
    private func formField<Content: View>(label: String, hint: Text?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(labelColor)
                if let hint {
                    Spacer()
                    hint
                }
            }
            content()
        }
    }

    @ViewBuilder
    private func styledTextField(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        let isFocused = focusedField == field
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(labelColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(fieldBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isFocused ? activeColor : fieldBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .focused($focusedField, equals: field)
            .animation(.easeInOut(duration: 0.14), value: isFocused)
            .animation(.easeInOut(duration: 0.14), value: selectedColor)
    }
}

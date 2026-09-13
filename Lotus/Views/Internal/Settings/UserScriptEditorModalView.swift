//
//  UserScriptEditorModalView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI

struct UserScriptEditorModalView: View {
    enum Mode {
        case create
        case edit(UserScript)

        var title: String {
            switch self {
            case .create: return "New Script or Style"
            case .edit(let s): return "Edit \"\(s.name)\""
            }
        }

        var subtitle: String {
            switch self {
            case .create: return "Inject a custom CSS stylesheet or JavaScript snippet into matching domains."
            case .edit: return "Update the script name, target domain, type, and code."
            }
        }

        var actionButtonTitle: String {
            switch self {
            case .create: return "Add Script"
            case .edit: return "Save Changes"
            }
        }
    }

    enum Field: Hashable {
        case name, domain, code
    }

    let mode: Mode
    let onSave: (UserScript) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var domainPattern: String
    @State private var type: UserScriptType
    @State private var runAt: UserScriptRunAt
    @State private var code: String
    @State private var isEnabled: Bool

    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var colorScheme

    private var existingId: UUID?

    init(mode: Mode, onSave: @escaping (UserScript) -> Void, onCancel: @escaping () -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.onCancel = onCancel
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _domainPattern = State(initialValue: "*")
            _type = State(initialValue: .css)
            _runAt = State(initialValue: .documentEnd)
            _code = State(initialValue: "")
            _isEnabled = State(initialValue: true)
            existingId = nil
        case .edit(let script):
            _name = State(initialValue: script.name)
            _domainPattern = State(initialValue: script.domainPattern)
            _type = State(initialValue: script.type)
            _runAt = State(initialValue: script.runAt)
            _code = State(initialValue: script.code)
            _isEnabled = State(initialValue: script.isEnabled)
            existingId = script.id
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Name
                    formField(label: "Name") {
                        styledTextField("My Dark Mode Style", text: $name, field: .name)
                    }

                    // Domain Pattern
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Domain Pattern")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(labelColor)
                        styledTextField("github.com, *reddit.com*, *", text: $domainPattern, field: .domain, design: .monospaced)
                        Text("Use * as wildcard. Examples: github.com, *reddit.com*, * for all pages")
                            .font(.system(size: 11))
                            .foregroundColor(subtitleColor)
                    }

                    HStack {
                        // Type
                        formField(label: "Type") {
                            Picker("", selection: $type) {
                                ForEach(UserScriptType.allCases) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        
                        // Run At (JS only)
                        if type == .javascript {
                            Spacer()
                            
                            formField(label: "Run At") {
                                Picker("", selection: $runAt) {
                                    ForEach(UserScriptRunAt.allCases) { r in
                                        Text(r.rawValue).tag(r)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                        }
                    }

                    // Code Editor
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Code")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(labelColor)
                        }
                        TextEditor(text: $code)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(minHeight: 200, maxHeight: 360)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(fieldBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(fieldBorder, lineWidth: 1)
                            )
                            .scrollContentBackground(.hidden)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 4)
                .padding(.bottom, 16)
            }

            Spacer(minLength: 16)

            // MARK: - Action Buttons
            HStack(spacing: 12) {
                // Cancel
                LotusDialogCancelButton(action: onCancel)

                Spacer()

                // Save
                LotusDialogActionButton(title: mode.actionButtonTitle, isDestructive: false, showsReturnKeycap: true) {
                    saveScript()
                }
                .disabled(!isValid)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 26)
            .padding(.top, 10)
        }
        .frame(width: 500)
        .frame(minHeight: 560)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .name
            }
        }
    }

    // MARK: - View Helpers

    @ViewBuilder
    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(labelColor)
            content()
        }
    }

    @ViewBuilder
    private func styledTextField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        design: Font.Design = .default
    ) -> some View {
        let isFocused = focusedField == field
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .regular, design: design))
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
                        isFocused
                            ? Color(nsColor: .controlAccentColor)
                            : fieldBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .focused($focusedField, equals: field)
            .animation(.easeInOut(duration: 0.14), value: isFocused)
    }

    private func saveScript() {
        var script = UserScript(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            domainPattern: domainPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "*"
                : domainPattern.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            code: code,
            isEnabled: isEnabled,
            runAt: runAt
        )
        if let existingId {
            script.id = existingId
        }
        onSave(script)
    }
}

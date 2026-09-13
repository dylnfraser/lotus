//
//  JavaScriptDialogView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/28/26.
//

import SwiftUI
import AppKit

enum JavaScriptDialogKind {
    case alert(message: String, completion: () -> Void)
    case confirm(message: String, completion: (Bool) -> Void)
    case prompt(prompt: String, defaultText: String?, completion: (String?) -> Void)
}

struct JavaScriptDialogRequest: Identifiable {
    let id = UUID()
    let host: String
    let kind: JavaScriptDialogKind
}

struct JavaScriptDialogView: View {
    @ObservedObject var browserState: BrowserState
    let request: JavaScriptDialogRequest
    @Environment(\.colorScheme) private var colorScheme

    @State private var inputText: String = ""
    @State private var hasHandled: Bool = false
    @FocusState private var isInputFocused: Bool

    init(browserState: BrowserState, request: JavaScriptDialogRequest) {
        self.browserState = browserState
        self.request = request
        if case .prompt(_, let defaultText, _) = request.kind {
            _inputText = State(initialValue: defaultText ?? "")
        } else {
            _inputText = State(initialValue: "")
        }
    }

    private var displayHost: String {
        request.host.isEmpty ? "This page" : request.host
    }

    private var messageText: String {
        switch request.kind {
        case .alert(let message, _):
            return message
        case .confirm(let message, _):
            return message
        case .prompt(let prompt, _, _):
            return prompt
        }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(colorScheme == .dark ? 0.40 : 0.20)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture {
                    handleCancel()
                }

            // Modal Card
            VStack(alignment: .leading, spacing: 0) {
                // Icon Squircle
                iconSquircle
                    .padding(.bottom, 14)

                // Title
                Text("“\(displayHost)”")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                    .lineLimit(2)
                    .padding(.bottom, 8)

                // Message Text
                if !messageText.isEmpty {
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(messageText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.68) : Color(nsColor: .secondaryLabelColor))
                            .lineSpacing(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 140)
                    .padding(.bottom, isPrompt ? 14 : 22)
                } else {
                    Spacer()
                        .frame(height: isPrompt ? 8 : 14)
                }

                // Prompt Input Box
                if isPrompt {
                    TextField("", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(colorScheme == .dark ? .white : Color(nsColor: .labelColor))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .onSubmit {
                            handleConfirm()
                        }
                        .padding(.bottom, 22)
                }

                // Buttons row
                HStack(spacing: 10) {
                    Spacer(minLength: 12)

                    if showsCancelButton {
                        LotusDialogCancelButton {
                            handleCancel()
                        }
                    }

                    LotusDialogActionButton(title: "OK", isDestructive: false, showsReturnKeycap: true) {
                        handleConfirm()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(width: 430)
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
        .onAppear {
            if isPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isInputFocused = true
                }
            }
        }
    }

    private var isPrompt: Bool {
        if case .prompt = request.kind {
            return true
        }
        return false
    }

    private var showsCancelButton: Bool {
        switch request.kind {
        case .alert:
            return false
        case .confirm, .prompt:
            return true
        }
    }

    @ViewBuilder
    private var iconSquircle: some View {
        let (color, iconName): (Color, String) = {
            switch request.kind {
            case .alert:
                return (Color(nsColor: .systemOrange), "exclamationmark.bubble.fill")
            case .confirm:
                return (Color(nsColor: .systemBlue), "questionmark.bubble.fill")
            case .prompt:
                return (Color(nsColor: .systemTeal), "text.bubble.fill")
            }
        }()

        ZStack {
            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1.5)

            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }

    private func handleConfirm() {
        guard !hasHandled else { return }
        hasHandled = true
        switch request.kind {
        case .alert(_, let completion):
            completion()
        case .confirm(_, let completion):
            completion(true)
        case .prompt(_, _, let completion):
            completion(inputText)
        }
        browserState.dismissJavaScriptDialog()
    }

    private func handleCancel() {
        guard !hasHandled else { return }
        hasHandled = true
        switch request.kind {
        case .alert(_, let completion):
            completion()
        case .confirm(_, let completion):
            completion(false)
        case .prompt(_, _, let completion):
            completion(nil)
        }
        browserState.dismissJavaScriptDialog()
    }
}

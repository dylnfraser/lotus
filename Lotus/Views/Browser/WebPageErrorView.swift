//
//  WebPageErrorView.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

struct WebPageErrorView: View {
    let error: PageLoadError
    let theme: BrowserChromeTheme
    let onRetry: () -> Void
    let onOpenHTTPFallback: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @State private var isRetrying: Bool = false
    @State private var showDetails: Bool = false

    private var foregroundPrimary: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color(nsColor: .labelColor)
    }

    private var foregroundSecondary: Color {
        colorScheme == .dark ? Color.white.opacity(0.60) : Color(nsColor: .secondaryLabelColor)
    }

    private var accentColor: Color {
        theme.themeColor ?? Color(nsColor: .controlAccentColor)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Clean native window background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top offset anchoring the error message slightly above the center
                Spacer()
                    .frame(height: 96)

                VStack(spacing: 20) {
                    // Larger Native macOS Style Error Icon
                    Image(systemName: error.systemImage)
                        .font(.system(size: 58, weight: .light))
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.65) : Color(nsColor: .secondaryLabelColor))
                        .padding(.bottom, 2)

                    // Title & Description
                    VStack(spacing: 8) {
                        Text(error.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(foregroundPrimary)
                            .multilineTextAlignment(.center)

                        Text(error.message)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(foregroundSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 460)
                    }

                    // Action Buttons Row (Try Again + Show Details + Insecure Fallback)
                    HStack(spacing: 10) {
                        Button {
                            isRetrying = true
                            onRetry()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                isRetrying = false
                            }
                        } label: {
                            Text("Try Again")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(accentColor)
                        .keyboardShortcut(.defaultAction)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showDetails.toggle()
                            }
                        } label: {
                            Text(showDetails ? "Hide Details" : "Show Details")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                        if error.isHTTPSEnforcedFailure, let fallback = onOpenHTTPFallback {
                            Button {
                                fallback()
                            } label: {
                                Text("Load Insecure HTTP")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                    .padding(.top, 4)

                    // Expanded Details Well
                    if showDetails {
                        VStack(alignment: .leading, spacing: 4) {
                            if let url = error.url {
                                Text("URL: \(url.absoluteString)")
                                    .lineLimit(2)
                            }
                            Text("Domain: \(error.domain)")
                            Text("Code: \(error.code)")
                            if !error.localizedDescription.isEmpty {
                                Text("Description: \(error.localizedDescription)")
                                    .lineLimit(3)
                            }
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(foregroundSecondary)
                        .padding(10)
                        .frame(maxWidth: 440, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 520)

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}

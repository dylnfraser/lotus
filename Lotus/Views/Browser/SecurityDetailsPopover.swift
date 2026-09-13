//
//  SecurityDetailsPopover.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import SwiftUI

struct SecurityDetailsPopover: View {
    @ObservedObject var browserState: BrowserState
    let tabId: UUID
    @Environment(\.colorScheme) private var colorScheme
    @State private var isCertificateExpanded: Bool = false

    private var currentURL: URL? {
        browserState.url(for: tabId)
    }

    private var host: String {
        currentURL?.host ?? "This Site"
    }

    private var isHTTPS: Bool {
        currentURL?.scheme?.lowercased() == "https"
    }

    private var isInternal: Bool {
        currentURL?.isLotusPage == true
    }

    private var certDetails: CertificateDetails? {
        browserState.certificateDetails(for: tabId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Security Badge & Summary
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(securityBadgeColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: securityBadgeIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(securityBadgeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(securityTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(host)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Text(securityDescription)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            // Certificate Details Section (for HTTPS)
            if isHTTPS {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isCertificateExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Certificate Information", systemImage: "doc.text.magnifyingglass")
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Image(systemName: isCertificateExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isCertificateExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            if let cert = certDetails {
                                certRow(label: "Issued To", value: cert.subjectCommonName)
                                if let org = cert.subjectOrganization {
                                    certRow(label: "Organization", value: org)
                                }
                                certRow(label: "Issued By", value: cert.issuerCommonName)
                                if let issuerOrg = cert.issuerOrganization {
                                    certRow(label: "CA Org", value: issuerOrg)
                                }
                                if let until = cert.validUntil {
                                    certRow(label: "Expires", value: until.formatted(date: .abbreviated, time: .omitted))
                                }
                                certRow(label: "Fingerprint", value: String(cert.sha256Fingerprint.prefix(23)) + "…")
                            } else {
                                Text("Verified by macOS system trust store (TLS 1.3)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                    }
                }

                Divider()
            }

            // Permissions Section
            if !isInternal {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Permissions for this site")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach(SitePermissionType.allCases) { perm in
                        permissionRow(for: perm)
                    }
                }

                Divider()

                Button {
                    browserState.startZapMode(for: tabId)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.accentColor)

                        Text("Zap Element on Page")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)

                        Spacer()

                        Text("⌘⌥Z")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    browserState.removeWebsiteData(for: host)
                } label: {
                    HStack {
                        Label("Clear Cookies & Data", systemImage: "trash")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(nsColor: .systemRed).opacity(0.85))
                        Spacer()
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func certRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 68, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func permissionRow(for perm: SitePermissionType) -> some View {
        let currentState = SitePermissionStore.shared.state(for: host, type: perm)

        return HStack {
            Label(perm.displayName, systemImage: perm.iconName)
                .font(.system(size: 12))
                .foregroundColor(.primary)

            Spacer()

            Picker("", selection: Binding(
                get: { currentState },
                set: { newState in
                    SitePermissionStore.shared.set(state: newState, for: host, type: perm)
                }
            )) {
                Text("Ask").tag(SitePermissionState.prompt)
                Text("Allow").tag(SitePermissionState.allow)
                Text("Block").tag(SitePermissionState.deny)
            }
            .untintedDropdown()
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 80)
        }
    }

    private var securityBadgeIcon: String {
        if isInternal { return "lotus" }
        if isHTTPS { return "lock.fill" }
        return "exclamationmark.triangle.fill"
    }

    private var securityBadgeColor: Color {
        if isInternal { return Color(nsColor: .systemPurple) }
        if isHTTPS { return Color(nsColor: .systemGreen) }
        return Color(nsColor: .systemOrange)
    }

    private var securityTitle: String {
        if isInternal { return "Internal Page" }
        if isHTTPS { return "Connection is Secure" }
        return "Not Secure"
    }

    private var securityDescription: String {
        if isInternal {
            return "This is a built-in Lotus application page running securely on your device."
        }
        if isHTTPS {
            return "Your information (passwords, messages, cookies) is private and encrypted when sent to this site."
        }
        return "You should not enter sensitive information on this site (e.g. passwords or credit cards), as your connection is not private."
    }
}

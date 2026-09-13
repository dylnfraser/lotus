//
//  TabItem.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import Foundation

struct TabItem: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var title: String
    var url: URL?
    var isPinned: Bool
    /// Sidebar folder this tab belongs to, if any. Pinned tabs never carry a
    /// folder (folders cannot be pinned). Optional so old sessions decode.
    var folderId: UUID?
    /// Dynamically discovered high-res favicon URL extracted from the page DOM.
    var customFaviconURL: URL?
    /// Timestamp of when the user last switched to or interacted with this tab.
    var lastViewedAt: Date?
    /// Whether audio playback is muted for this tab.
    var isMuted: Bool = false
    /// Whether this tab's webview resources are currently suspended to save memory.
    var isSnoozed: Bool = false
    /// The profile this tab belongs to (nil implies the default profile).
    var profileId: UUID? = nil

    init(
        id: UUID = UUID(),
        title: String,
        url: URL? = nil,
        isPinned: Bool = false,
        folderId: UUID? = nil,
        customFaviconURL: URL? = nil,
        lastViewedAt: Date? = Date(),
        isMuted: Bool = false,
        isSnoozed: Bool = false,
        profileId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.folderId = folderId
        self.customFaviconURL = customFaviconURL
        self.lastViewedAt = lastViewedAt
        self.isMuted = isMuted
        self.isSnoozed = isSnoozed
        self.profileId = profileId
    }

    enum CodingKeys: String, CodingKey {
        case id, title, url, isPinned, folderId, customFaviconURL, lastViewedAt, isMuted, isSnoozed, profileId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.folderId = try container.decodeIfPresent(UUID.self, forKey: .folderId)
        self.customFaviconURL = try container.decodeIfPresent(URL.self, forKey: .customFaviconURL)
        self.lastViewedAt = try container.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        self.isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        self.isSnoozed = try container.decodeIfPresent(Bool.self, forKey: .isSnoozed) ?? false
        self.profileId = try container.decodeIfPresent(UUID.self, forKey: .profileId)
    }

    var faviconURL: URL? {
        if url?.isLotusPage == true { return nil }
        if let custom = customFaviconURL { return custom }
        guard let host = url?.host, !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/favicon.ico"
        return components.url
    }
}

extension TabItem {
    static let samples: [TabItem] = [
        TabItem(title: "Apple", url: URL(string: "https://www.apple.com"), isPinned: true),
    ]
}

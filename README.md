# Lotus Browser

Lotus is a native, lightweight macOS web browser built entirely in Swift and SwiftUI, utilizing WebKit (`WKWebView`). It features a vertical-tab sidebar, split-view multitasking, tab folders, a command palette, adaptive site theming, and native SwiftUI internal pages within a sandboxed environment, requiring no third-party dependencies.

## Core Features

*   **Vertical Tabstrip & Sidebar:** Tabs are managed in a collapsible, resizable vertical sidebar. Includes drag-and-drop reordering, multi-column pinned tabs, and multi-tab range selection (`⇧`+click) for batch operations.
*   **Tab Folders:** Organize tabs into collapsible, color-coded folders. Folder state and tab contiguity are preserved across sessions and tab movements.
*   **Split View:** Support for side-by-side tab viewing with magnetic resize snapping (50/50, 1/3, 2/3) and custom ratio persistence.
*   **Content Blocking & Privacy:** Declarative WebKit rule blocking for ads and trackers. Includes specialized script handling for video ads and anti-fingerprinting measures (normalizing hardware metrics and injecting session noise).
*   **Command Palette (`⌘T` / `⌘L`):** Fast launcher and search bar accessible via keyboard shortcuts. Provides in-memory search suggestions and domain heuristics.
*   **Adaptive Theming:** Tints browser chrome based on dominant colors extracted from site favicons via CoreImage, calculating contrast luminance for optimal text readability.
*   **Native Internal Pages:**
    *   `lotus://history` (`⌘Y`): Searchable browsing history.
    *   `lotus://downloads` (`⌘⌥L`): Download manager with progress tracking.
    *   `lotus://settings` (`⌘,`): Native application preferences and shield management.
*   **In-Page Search (`⌘F`):** Floating find bar with match counts and instant highlight navigation.
*   **Session Management:** Atomically writes session snapshots (tabs, folders, split views, zoom levels) to Application Support for recovery. Includes closed tab restoration (`⌘⇧T`).
*   **Picture-in-Picture:** Automatically transitions playing HTML5 videos into Picture-in-Picture mode when switching tabs.

## System Requirements

*   **macOS 27.0+** (Apple Silicon or Intel)
*   **Xcode 16+** with matching macOS SDK
*   Swift 5 toolchain

## Building the Project

Clone the repository:
```sh
git clone https://github.com/dylanfraser/Lotus.git
cd Lotus

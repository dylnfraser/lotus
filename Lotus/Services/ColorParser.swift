//
//  ColorParser.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/20/26.
//

import SwiftUI

struct ParsedThemeColor: Equatable {
    let color: Color
    let nsColor: NSColor
    let isLight: Bool
}

enum ColorParser {
    static func parse(_ string: String) -> ParsedThemeColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.hasPrefix("#") {
            return parseHex(trimmed)
        } else if trimmed.hasPrefix("rgb") {
            return parseRGB(trimmed)
        }
        return nil
    }

    private static func parseHex(_ hex: String) -> ParsedThemeColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if hexSanitized.count == 6 {
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            let ns = NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
            return ParsedThemeColor(color: Color(nsColor: ns), nsColor: ns, isLight: lum > 0.55)
        }
        return nil
    }

    private static func parseRGB(_ rgbString: String) -> ParsedThemeColor? {
        let cleaned = rgbString
            .replacingOccurrences(of: "rgba(", with: "")
            .replacingOccurrences(of: "rgb(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let components = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count >= 3,
              let r = Double(components[0]),
              let g = Double(components[1]),
              let b = Double(components[2]) else { return nil }
        let a = components.count >= 4 ? (Double(components[3]) ?? 1.0) : 1.0
        if a < 0.05 { return nil }
        let rNorm = r / 255.0
        let gNorm = g / 255.0
        let bNorm = b / 255.0
        let lum = 0.299 * rNorm + 0.587 * gNorm + 0.114 * bNorm
        let ns = NSColor(srgbRed: rNorm, green: gNorm, blue: bNorm, alpha: a)
        return ParsedThemeColor(color: Color(nsColor: ns), nsColor: ns, isLight: lum > 0.55)
    }

    static func isLight(color: NSColor) -> Bool {
        guard let srgb = color.usingColorSpace(.sRGB) else { return false }
        let lum = 0.299 * Double(srgb.redComponent) + 0.587 * Double(srgb.greenComponent) + 0.114 * Double(srgb.blueComponent)
        return lum > 0.55
    }
}

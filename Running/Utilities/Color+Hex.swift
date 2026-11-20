import SwiftUI

// MARK: - Color Extension for Hex
extension Color { 
    init?(hex: String) { 
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "").uppercased()
        // Harmonize legacy raw RGB preset group colors for OLED dark mode
        switch hexSanitized {
        case "FF5733":
            self.init(red: 0.96, green: 0.36, blue: 0.28)
            return
        case "3357FF":
            self.init(red: 0.18, green: 0.45, blue: 0.96)
            return
        case "33FF57":
            self.init(red: 0.15, green: 0.82, blue: 0.38)
            return
        case "FF8C33":
            self.init(red: 1.00, green: 0.50, blue: 0.05)
            return
        case "8C33FF":
            self.init(red: 0.62, green: 0.38, blue: 0.98)
            return
        case "FF3380":
            self.init(red: 0.96, green: 0.32, blue: 0.56)
            return
        default:
            break
        }
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b) 
    } 
}

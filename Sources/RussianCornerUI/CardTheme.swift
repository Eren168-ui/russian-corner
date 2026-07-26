import SwiftUI

public struct CardThemePalette {
    public let background: Color
    public let primary: Color
    public let secondary: Color
    public let muted: Color
    public let accent: Color
    public let border: Color
    public let accentSurface: Color
}

public enum CardTheme {
    public static func palette(
        for colorScheme: ColorScheme
    ) -> CardThemePalette {
        switch colorScheme {
        case .dark:
            CardThemePalette(
                background: Color(hex: 0x262624),
                primary: Color(hex: 0xFAF9F5),
                secondary: Color(hex: 0xC3C0B6),
                muted: Color(hex: 0xB7B5A9),
                accent: Color(hex: 0xD97757),
                border: Color(hex: 0x3E3E38),
                accentSurface: Color(hex: 0x141413)
            )
        default:
            CardThemePalette(
                background: Color(hex: 0xFAF9F5),
                primary: Color(hex: 0x2A2620),
                secondary: Color(hex: 0x3D3929),
                muted: Color(hex: 0x83827D),
                accent: Color(hex: 0xC96442),
                border: Color(hex: 0xDAD9D4),
                accentSurface: Color(hex: 0xF0EEE7)
            )
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

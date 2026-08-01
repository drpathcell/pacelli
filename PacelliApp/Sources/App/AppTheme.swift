import SwiftUI

/// Colour schemes ported from the Flutter app
/// (`lib/config/theme/color_schemes.dart`): pacelli (sage/teal),
/// claude (warm purple), gemini (ocean blue). Stored locally
/// (@AppStorage — SharedPreferences parity), never in Firestore.
enum AppColorSchemeChoice: String, CaseIterable, Identifiable {
    case pacelli, claude, gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pacelli: String(localized: "Pacelli")
        case .claude: String(localized: "Claude")
        case .gemini: String(localized: "Gemini")
        }
    }

    var lightPrimary: Color {
        switch self {
        case .pacelli: Color(red: 0x7E / 255, green: 0xA8 / 255, blue: 0x7E / 255)
        case .claude: Color(red: 0x8B / 255, green: 0x6C / 255, blue: 0xC1 / 255)
        case .gemini: Color(red: 0x4A / 255, green: 0x86 / 255, blue: 0xC8 / 255)
        }
    }

    var darkPrimary: Color {
        switch self {
        case .pacelli: Color(red: 0x6B / 255, green: 0xA3 / 255, blue: 0xA0 / 255)
        case .claude: Color(red: 0xA7 / 255, green: 0x8B / 255, blue: 0xDB / 255)
        case .gemini: Color(red: 0x6B / 255, green: 0xA3 / 255, blue: 0xE0 / 255)
        }
    }

    /// Adaptive tint — resolves per the current light/dark appearance.
    var tint: Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(
                    traits.userInterfaceStyle == .dark ? darkPrimary : lightPrimary)
            })
    }
}

enum AppThemeModeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum ThemeStorageKeys {
    static let colorScheme = "pacelli_color_scheme"
    static let themeMode = "pacelli_theme_mode"
}

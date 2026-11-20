import CoreText
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Splash & welcome background.
    static let palsIndigo = Color(hex: 0x1800E8)
    /// Primary action blue (arrow & "Let's Go!" buttons).
    static let palsBlue = Color(hex: 0x0431FB)
    /// Illustration accent.
    static let palsPink = Color(hex: 0xFD3D9C)
    /// Light screen background (off-white).
    static let palsOffWhite = Color(hex: 0xF7F7F4)
    static let palsInk = Color(hex: 0x0A0A0A)
}

/// Brand typeface: Outfit (variable font bundled in Fonts/), used at different weights
/// for everything — black for headlines, bold for buttons, semibold for labels, regular for body.
enum PalsFont {
    static let name = "Outfit-Thin" // variable font; weight is set via the wght axis

    enum Weight: CGFloat {
        case regular = 400, medium = 500, semibold = 600, bold = 700, extraBold = 800, black = 900
    }

    /// Registers the bundled font for this process. Call once at launch.
    static func register() {
        guard let url = Bundle.main.url(forResource: "Outfit-Variable", withExtension: "ttf") else {
            assertionFailure("Outfit-Variable.ttf is missing from the app bundle")
            return
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Outfit at the given weight. Scales with Dynamic Type.
    static func uiFont(size: CGFloat, weight: Weight, relativeTo style: UIFont.TextStyle) -> UIFont {
        let wghtAxis = 0x77676874 // 'wght'
        let descriptor = UIFontDescriptor(name: name, size: size)
            .addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight.rawValue]])
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: size))
    }
}

extension Font {
    /// Labels and buttons (semibold by default).
    static func pals(_ size: CGFloat, weight: PalsFont.Weight = .semibold,
                     relativeTo style: UIFont.TextStyle = .body) -> Font {
        Font(PalsFont.uiFont(size: size, weight: weight, relativeTo: style))
    }

    /// Running text and secondary lines.
    static func palsBody(_ size: CGFloat) -> Font {
        pals(size, weight: .regular)
    }

    /// Big headlines.
    static func palsDisplay(_ size: CGFloat) -> Font {
        pals(size, weight: .black, relativeTo: .largeTitle)
    }
}

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

/// The app's motion vocabulary. Pick an animation by what it's for, not by its numbers, so the
/// same kind of interaction always moves the same way. UI motion stays quick (≈0.1–0.4 s),
/// eases out, and barely bounces; only rare, playful moments (pranks, finishing an activity) bounce.
enum Motion {
    // Touch feedback: instant on press, a touch slower on release.
    static let pressDown = Animation.easeOut(duration: 0.1)
    static let pressUp = Animation.easeOut(duration: 0.16)

    // Things appearing and leaving. Leaving is never slower than arriving.
    static let appear = Animation.easeOut(duration: 0.2)
    static let disappear = Animation.easeOut(duration: 0.2)

    /// Picking one thing out of several: a chip, a card in a fan, a circle.
    static let select = Animation.spring(duration: 0.25, bounce: 0.15)
    /// Opening or closing in place: a deck fanning out, a bubble growing, a row expanding.
    static let expand = Animation.spring(duration: 0.35, bounce: 0.15)
    /// Values changing on screen: progress, counts, a list updating. No bounce.
    static let update = Animation.spring(duration: 0.4, bounce: 0)
    /// Moving between whole screens or onboarding steps.
    static let screen = Animation.easeInOut(duration: 0.35)
    /// A card or panel sliding up into view.
    static let sheet = Animation.spring(duration: 0.45, bounce: 0.15)

    // Today's card draw.
    static let shuffle = Animation.spring(duration: 0.22, bounce: 0.2)
    static let flip = Animation.spring(duration: 0.7, bounce: 0.2)

    // Rare, playful moments: allowed to bounce.
    static let pop = Animation.spring(duration: 0.35, bounce: 0.5)
    static let celebrate = Animation.spring(duration: 0.5, bounce: 0.3)
    static let shake = Animation.linear(duration: 0.45)
    static let punchIn = Animation.spring(duration: 0.12)
    static let punchOut = Animation.spring(duration: 0.4, bounce: 0.3)
}

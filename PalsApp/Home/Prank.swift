import SwiftUI

/// Silly punishments you can send to a pal who skipped today's activity.
enum PrankKind: String, CaseIterable, Identifiable, Hashable {
    case slap, egg, italian, iceBucket

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .slap: "👋"
        case .egg: "🥚"
        case .italian: "🤌"
        case .iceBucket: "🧊"
        }
    }

    var title: String {
        switch self {
        case .slap: "Slap"
        case .egg: "Egg"
        case .italian: "Ma che fai"
        case .iceBucket: "Ice bucket"
        }
    }

    /// Short description shown on the option card.
    var pitch: String {
        switch self {
        case .slap: "A loud one, right across the screen."
        case .egg: "Cracked on their head. Yolk everywhere."
        case .italian: "The Italian hand. What are you doing?!"
        case .iceBucket: "A bucket of ice water, head to toe."
        }
    }

    /// The comic word that pops up on impact.
    var sound: String {
        switch self {
        case .slap: "SLAP!"
        case .egg: "CRACK!"
        case .italian: "MA CHE FAI?!"
        case .iceBucket: "BRRR!"
        }
    }

    /// Past tense for "Pasquale got slapped."
    var pastTense: String {
        switch self {
        case .slap: "slapped"
        case .egg: "egged"
        case .italian: "told off"
        case .iceBucket: "iced"
        }
    }

    func receivedLine(from name: String) -> String {
        switch self {
        case .slap: "\(name) slapped you!"
        case .egg: "\(name) egged you!"
        case .italian: "\(name): ma che fai?! 🤌"
        case .iceBucket: "\(name) iced you! 🥶"
        }
    }
}

/// A prank waiting to be played when you open the app.
struct IncomingPrank: Identifiable, Equatable {
    let id = UUID()
    let kind: PrankKind
    let fromName: String
    let fromColor: Color
    /// Set when you're previewing a prank before sending it; holds who it's for.
    var previewTarget: String?
    /// Set when you just sent this prank; played on your screen as a confirmation.
    var sentTo: String?
    /// Subtitle on the "X slapped you!" card.
    var reason = "…because you haven't done today's activity."
}

extension IncomingPrank {
    /// Who does the pranking in the animation: your pal normally, you when you're sending or previewing one.
    var pranker: PrankFace {
        sentTo != nil || previewTarget != nil
            ? .you
            : PrankFace(name: fromName, color: fromColor, isYou: false)
    }

    /// Who gets pranked in the animation: you normally, your pal when you're sending or previewing one.
    var victim: PrankFace {
        if let sentTo { return PrankFace(name: sentTo, color: fromColor, isYou: false) }
        if let previewTarget { return PrankFace(name: previewTarget, color: .palsBlue, isYou: false) }
        return .you
    }
}

/// A face shown in a prank animation: a pal's memoji, or your own photo.
struct PrankFace: View {
    let name: String
    var color: Color = .palsIndigo
    let isYou: Bool
    var size: CGFloat = 80

    static let you = PrankFace(name: "You", isYou: true)

    func sized(_ size: CGFloat) -> PrankFace {
        PrankFace(name: name, color: color, isYou: isYou, size: size)
    }

    var body: some View {
        if isYou {
            PalsAvatar(name: UserDefaults.standard.string(forKey: "profileName") ?? "You",
                       photo: ProfilePhotoStore.load(), size: size, glass: false)
        } else {
            PalsAvatar(name: name, color: color, size: size, glass: false)
        }
    }
}

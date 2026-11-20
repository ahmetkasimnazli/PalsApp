import SwiftUI

/// Silly punishments you can send to a pal who skipped today's activity.
enum PrankKind: String, CaseIterable, Identifiable, Hashable {
    case slap, egg

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .slap: "👋"
        case .egg: "🥚"
        }
    }

    var title: String {
        switch self {
        case .slap: "Slap"
        case .egg: "Egg"
        }
    }

    /// Short description shown on the option card.
    var pitch: String {
        switch self {
        case .slap: "A loud one, right across the screen."
        case .egg: "Cracked on their head. Yolk everywhere."
        }
    }

    /// The comic word that pops up on impact.
    var sound: String {
        switch self {
        case .slap: "SLAP!"
        case .egg: "CRACK!"
        }
    }

    /// Past tense for "Pasquale got slapped."
    var pastTense: String {
        switch self {
        case .slap: "slapped"
        case .egg: "egged"
        }
    }

    func receivedLine(from name: String) -> String {
        switch self {
        case .slap: "\(name) slapped you!"
        case .egg: "\(name) egged you!"
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
    var reason = "…because you haven't done today's walk."
}

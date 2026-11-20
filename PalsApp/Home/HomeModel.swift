import Observation
import SwiftUI

struct Friend: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    var isActive: Bool
    var doneToday: Bool
    /// The prank you already sent them today (one per day).
    var prankedToday: PrankKind?
}

struct PalsCircle: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var emoji: String = "👯"
    var color: Color = .palsIndigo
    /// The daily activity everyone in the circle does.
    var activity: String = "Walk for 5 minutes"
    /// Days in a row the whole circle has completed the activity.
    var streak: Int = 0
    var friends: [Friend]
}

struct Activity: Hashable {
    /// Headline lines; the last one goes on the lime band.
    let lines: [String]
    let highlight: String
    let duration: Int // seconds

    static let today = Activity(lines: ["Walk for"], highlight: "5 minutes.", duration: 5 * 60)
}

/// State behind the home screen. Friends are mock data until there's a backend.
@Observable
final class HomeModel {
    private(set) var circles: [PalsCircle]
    var selectedCircleID: PalsCircle.ID
    let todayActivity = Activity.today

    /// Presented from the home screen and from the prank card.
    var showingActivity = false
    /// A prank waiting to be played on screen.
    var incomingPrank: IncomingPrank?
    /// Photo you snapped when finishing today's activity (demo: kept in memory).
    var proofPhoto: UIImage?

    private(set) var streakDays: Int
    private(set) var freezes: Int = 2
    private(set) var completedToday: Bool

    private let defaults = UserDefaults.standard
    private static let streakKey = "streakDays"
    private static let lastCompletedKey = "lastCompletedDate"

    init() {
        let close = PalsCircle(name: "Close Friends", emoji: "🫶", color: .palsIndigo, activity: "Walk for 5 minutes", streak: 13, friends: [
            Friend(name: "Alessia", color: .palsPink, isActive: true, doneToday: true),
            Friend(name: "Can", color: .palsBlue, isActive: true, doneToday: false),
            Friend(name: "Kimia", color: .palsPink, isActive: false, doneToday: true),
            Friend(name: "Pasquale", color: .palsIndigo, isActive: true, doneToday: false),
        ])
        let gym = PalsCircle(name: "Gym Crew", emoji: "💪", color: .palsPink, activity: "20 push-ups", streak: 6, friends: [
            Friend(name: "Valentina", color: .palsBlue, isActive: true, doneToday: true),
            Friend(name: "Igor", color: .palsPink, isActive: false, doneToday: false),
            Friend(name: "Samuel", color: .palsIndigo, isActive: true, doneToday: true),
            Friend(name: "Mahsa", color: .palsIndigo, isActive: true, doneToday: false),
        ])
        let family = PalsCircle(name: "Family", emoji: "🏡", color: .palsBlue, activity: "Drink 8 glasses of water", streak: 21, friends: [
            Friend(name: "Antonio", color: .palsPink, isActive: false, doneToday: true),
            Friend(name: "Gizem", color: .palsBlue, isActive: true, doneToday: false),
        ])
        circles = [close, gym, family]
        selectedCircleID = close.id

        let lastCompleted = defaults.object(forKey: Self.lastCompletedKey) as? Date
        completedToday = lastCompleted.map(Calendar.current.isDateInToday) ?? false
        // Keep the streak only if the last activity was today or yesterday.
        let stillAlive = lastCompleted.map { Calendar.current.isDateInToday($0) || Calendar.current.isDateInYesterday($0) } ?? false
        streakDays = stillAlive ? defaults.integer(forKey: Self.streakKey) : 0
        if streakDays == 0 && lastCompleted == nil { streakDays = 12 } // demo value for the first run

        // Demo: until there's a backend, a pal "pranks" you whenever you open the app
        // without having done today's activity.
        if !completedToday, let pranker = close.friends.last {
            incomingPrank = IncomingPrank(
                kind: PrankKind.allCases.randomElement() ?? .slap,
                fromName: pranker.name,
                fromColor: pranker.color
            )
        }
    }

    var selectedCircle: PalsCircle {
        circles.first { $0.id == selectedCircleID } ?? circles[0]
    }

    var activeCount: Int { selectedCircle.friends.filter(\.isActive).count }

    /// Share of the circle (you included) that finished today's activity.
    var circleProgress: Double {
        let friends = selectedCircle.friends
        let done = friends.filter(\.doneToday).count + (completedToday ? 1 : 0)
        return Double(done) / Double(friends.count + 1)
    }

    var doneSummary: String {
        let friends = selectedCircle.friends
        let done = friends.filter(\.doneToday).count + (completedToday ? 1 : 0)
        return "\(done)/\(friends.count + 1) done today"
    }

    /// Pals in the selected circle who skipped today and haven't been pranked yet.
    var skippedFriends: [Friend] { selectedCircle.friends.filter { !$0.doneToday && $0.prankedToday == nil } }

    /// Share of a circle (you included) that finished today's activity.
    func progress(of circle: PalsCircle) -> Double {
        let done = circle.friends.filter(\.doneToday).count + (completedToday ? 1 : 0)
        return Double(done) / Double(circle.friends.count + 1)
    }

    func doneCount(in circle: PalsCircle) -> Int {
        circle.friends.filter(\.doneToday).count + (completedToday ? 1 : 0)
    }

    /// Demo: creates a circle with a few pals from your other circles.
    func createCircle(name: String, emoji: String, activity: String, memberIDs: Set<Friend.ID>) {
        var seen = Set<String>()
        let members = circles.flatMap(\.friends)
            .filter { memberIDs.contains($0.id) && seen.insert($0.name).inserted }
            .map { Friend(name: $0.name, color: $0.color, isActive: $0.isActive, doneToday: false) }
        let colors: [Color] = [.palsIndigo, .palsPink, .palsBlue]
        circles.append(PalsCircle(name: name, emoji: emoji, color: colors[circles.count % colors.count],
                                  activity: activity, streak: 0, friends: members))
    }

    /// Everyone you know, once each (for picking members of a new circle).
    var allPals: [Friend] {
        var seen = Set<String>()
        return circles.flatMap(\.friends).filter { seen.insert($0.name).inserted }
    }

    func friend(id: Friend.ID) -> Friend? {
        circles.lazy.flatMap(\.friends).first { $0.id == id }
    }

    func sendPrank(_ kind: PrankKind, to friendID: Friend.ID) {
        // TODO: send to the backend so it's played on their phone.
        for c in circles.indices {
            for f in circles[c].friends.indices where circles[c].friends[f].id == friendID {
                circles[c].friends[f].prankedToday = kind
            }
        }
    }

    /// Plays a prank on your own screen so you can see what your pal will get.
    func previewPrank(_ kind: PrankKind, for friend: Friend) {
        incomingPrank = IncomingPrank(kind: kind, fromName: "You", fromColor: .palsIndigo, previewTarget: friend.name)
    }

    /// Plays the prank you just sent on your own screen, so sending feels like something happened.
    func playSentPrank(_ kind: PrankKind, to friend: Friend) {
        incomingPrank = IncomingPrank(kind: kind, fromName: friend.name, fromColor: friend.color, sentTo: friend.name)
    }

    /// Demo stand-in for a push from a pal: someone in your circle pranks you right now.
    func receiveDemoPrank() {
        let pals = selectedCircle.friends
        let pranker = pals.filter(\.doneToday).randomElement() ?? pals.randomElement()
        guard let pranker else { return }
        incomingPrank = IncomingPrank(
            kind: PrankKind.allCases.randomElement() ?? .slap,
            fromName: pranker.name,
            fromColor: pranker.color,
            reason: completedToday
                ? "…just for fun. You already walked today 😇"
                : "…because you haven't done today's walk."
        )
    }

    /// Demo helper: undo today's activity and sent pranks so the flow can be shown again.
    func resetToday() {
        proofPhoto = nil
        if completedToday {
            completedToday = false
            streakDays = max(0, streakDays - 1)
            defaults.set(streakDays, forKey: Self.streakKey)
            defaults.set(Calendar.current.date(byAdding: .day, value: -1, to: .now), forKey: Self.lastCompletedKey)
        }
        for c in circles.indices {
            for f in circles[c].friends.indices {
                circles[c].friends[f].prankedToday = nil
            }
        }
    }

    func completeTodayActivity() {
        guard !completedToday else { return }
        completedToday = true
        streakDays += 1
        defaults.set(streakDays, forKey: Self.streakKey)
        defaults.set(Date(), forKey: Self.lastCompletedKey)
    }
}

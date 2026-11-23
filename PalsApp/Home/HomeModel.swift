import Observation
import SwiftUI

struct Friend: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    var isActive: Bool
    /// Did today's activity.
    var doneToday: Bool
    /// The prank you already sent them today (one per day).
    var prankedToday: PrankKind?
}

/// Something a circle can do on a day. Anyone in the circle can add one to the pool.
struct CircleActivity: Identifiable, Hashable {
    let id = UUID()
    var emoji: String
    var title: String
    /// Length of the timer; `nil` means there's no timer, you just mark it done.
    var minutes: Int?
    var addedBy: String = "Pals"

    var durationLabel: String {
        guard let minutes else { return "No timer" }
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    /// Ready-made ideas offered when creating a circle or adding an activity.
    static let suggestions: [CircleActivity] = [
        CircleActivity(emoji: "🚶", title: "Walk for 5 minutes", minutes: 5),
        CircleActivity(emoji: "📚", title: "Read 10 pages", minutes: nil),
        CircleActivity(emoji: "🧘", title: "Meditate 5 minutes", minutes: 5),
        CircleActivity(emoji: "💪", title: "20 push-ups", minutes: nil),
        CircleActivity(emoji: "💧", title: "Drink 8 glasses of water", minutes: nil),
        CircleActivity(emoji: "📵", title: "No phone for 1 hour", minutes: 60),
        CircleActivity(emoji: "🤸", title: "Stretch 10 minutes", minutes: 10),
        CircleActivity(emoji: "🧎", title: "Plank for 1 minute", minutes: 1),
    ]

    static func suggestion(_ title: String) -> CircleActivity {
        suggestions.first { $0.title == title } ?? CircleActivity(emoji: "✨", title: title, minutes: nil)
    }
}

struct PalsCircle: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var emoji: String = "👯"
    var color: Color = .palsIndigo
    /// Every activity the circle has added. One of them is picked for everyone each day.
    var pool: [CircleActivity]
    /// Days in a row the whole circle has completed the activity.
    var streak: Int = 0
    var friends: [Friend]

    /// The activity everyone in the circle does today.
    var today: CircleActivity { pick(for: .now) }

    /// Tomorrow's activity, shown ahead so people can plan for it.
    var tomorrow: CircleActivity {
        pick(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
    }

    /// Picks the day's activity from the pool, never the same as the day before.
    ///
    /// It's worked out from the circle's name and the date rather than chosen at random, so every
    /// member's phone lands on the same activity without a server deciding it.
    func pick(for date: Date) -> CircleActivity {
        guard pool.count > 1 else { return pool.first ?? CircleActivity.suggestions[0] }
        let index = rawIndex(for: date)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let repeated = index == rawIndex(for: yesterday)
        return pool[repeated ? (index + 1) % pool.count : index]
    }

    private func rawIndex(for date: Date) -> Int {
        // FNV-1a: stable across launches and devices (unlike `hashValue`).
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(name)|\(PalsDay.key(date))".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return Int(hash % UInt64(pool.count))
    }
}

enum PalsDay {
    /// "2026-11-23" in the user's time zone.
    static func key(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// State behind the home screen. Friends are mock data until there's a backend.
@Observable
final class HomeModel {
    private(set) var circles: [PalsCircle]
    var selectedCircleID: PalsCircle.ID

    /// The activity whose session (timer / proof) is open.
    var activeActivity: CircleActivity?
    /// A prank waiting to be played on screen.
    var incomingPrank: IncomingPrank?
    /// Photo you snapped when finishing today's activity (demo: kept in memory).
    var proofPhoto: UIImage?

    private(set) var streakDays: Int
    private(set) var freezes: Int = 2
    /// Circles where you've done today's activity.
    private(set) var doneCircles: Set<PalsCircle.ID> = []

    private let defaults = UserDefaults.standard
    private static let streakKey = "streakDays"
    private static let lastCompletedKey = "lastCompletedDate"
    private static let myDoneKey = "myDoneToday"      // ["<day>|<circle name>"]

    init() {
        var close = PalsCircle(name: "Close Friends", emoji: "🫶", color: .palsIndigo, pool: [
            CircleActivity.suggestion("Walk for 5 minutes"),
            CircleActivity.suggestion("Read 10 pages"),
            CircleActivity.suggestion("Meditate 5 minutes"),
            CircleActivity.suggestion("Drink 8 glasses of water"),
        ], streak: 13, friends: [
            Friend(name: "Alessia", color: .palsPink, isActive: true, doneToday: true),
            Friend(name: "Can", color: .palsBlue, isActive: true, doneToday: false),
            Friend(name: "Kimia", color: .palsPink, isActive: false, doneToday: true),
            Friend(name: "Pasquale", color: .palsIndigo, isActive: true, doneToday: false),
        ])
        close.pool[2].addedBy = "Kimia"
        close.pool[3].addedBy = "Pasquale"

        let gym = PalsCircle(name: "Gym Crew", emoji: "💪", color: .palsPink, pool: [
            CircleActivity.suggestion("20 push-ups"),
            CircleActivity.suggestion("Plank for 1 minute"),
            CircleActivity.suggestion("Stretch 10 minutes"),
            CircleActivity(emoji: "🏃", title: "Run 2 km", minutes: 15, addedBy: "Igor"),
        ], streak: 6, friends: [
            Friend(name: "Valentina", color: .palsBlue, isActive: true, doneToday: true),
            Friend(name: "Igor", color: .palsPink, isActive: false, doneToday: false),
            Friend(name: "Samuel", color: .palsIndigo, isActive: true, doneToday: true),
            Friend(name: "Mahsa", color: .palsIndigo, isActive: true, doneToday: false),
        ])

        let family = PalsCircle(name: "Family", emoji: "🏡", color: .palsBlue, pool: [
            CircleActivity.suggestion("Drink 8 glasses of water"),
            CircleActivity(emoji: "🍝", title: "No phones at dinner", minutes: nil, addedBy: "Antonio"),
        ], streak: 21, friends: [
            Friend(name: "Antonio", color: .palsPink, isActive: false, doneToday: true),
            Friend(name: "Gizem", color: .palsBlue, isActive: true, doneToday: false),
        ])

        circles = [close, gym, family]
        selectedCircleID = close.id

        let lastCompleted = defaults.object(forKey: Self.lastCompletedKey) as? Date
        // Keep the streak only if the last activity was today or yesterday.
        let stillAlive = lastCompleted.map { Calendar.current.isDateInToday($0) || Calendar.current.isDateInYesterday($0) } ?? false
        streakDays = stillAlive ? defaults.integer(forKey: Self.streakKey) : 0
        if streakDays == 0 && lastCompleted == nil { streakDays = 12 } // demo value for the first run
        restoreDoneCircles()

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

    func circle(id: PalsCircle.ID) -> PalsCircle? {
        circles.first { $0.id == id }
    }

    // MARK: - You, today

    func isDone(in circle: PalsCircle) -> Bool { doneCircles.contains(circle.id) }

    /// You've done today's activity in the circle on your orbit.
    var completedToday: Bool { isDone(in: selectedCircle) }

    /// Opens today's activity in the circle on your orbit.
    func startActivity() {
        activeActivity = selectedCircle.today
    }

    func completeTodayActivity(in circleID: PalsCircle.ID? = nil) {
        let circleID = circleID ?? selectedCircleID
        doneCircles.insert(circleID)
        saveDoneCircles()
        // The streak grows once a day, the first time you finish a circle's activity.
        let last = defaults.object(forKey: Self.lastCompletedKey) as? Date
        guard !(last.map(Calendar.current.isDateInToday) ?? false) else { return }
        streakDays += 1
        defaults.set(streakDays, forKey: Self.streakKey)
        defaults.set(Date(), forKey: Self.lastCompletedKey)
    }

    // MARK: - Circle progress

    var activeCount: Int { selectedCircle.friends.filter(\.isActive).count }

    /// Share of the circle (you included) that finished today's activity.
    var circleProgress: Double { progress(of: selectedCircle) }

    /// Pals in the selected circle who skipped today and haven't been pranked yet.
    var skippedFriends: [Friend] { selectedCircle.friends.filter { !$0.doneToday && $0.prankedToday == nil } }

    func progress(of circle: PalsCircle) -> Double {
        Double(doneCount(in: circle)) / Double(circle.friends.count + 1)
    }

    func doneCount(in circle: PalsCircle) -> Int {
        circle.friends.filter(\.doneToday).count + (isDone(in: circle) ? 1 : 0)
    }

    /// Who did today's activity (you first, as "You").
    func peopleDone(in circle: PalsCircle) -> [Friend] {
        var people = circle.friends.filter(\.doneToday)
        if isDone(in: circle) {
            people.insert(Friend(name: "You", color: .palsIndigo, isActive: true, doneToday: true), at: 0)
        }
        return people
    }

    // MARK: - Activity pool (anyone in the circle can add)

    func addActivity(_ activity: CircleActivity, to circleID: PalsCircle.ID) {
        guard let index = circles.firstIndex(where: { $0.id == circleID }) else { return }
        var activity = activity
        activity.addedBy = "You"
        circles[index].pool.append(activity)
    }

    // MARK: - Circles

    /// Demo: creates a circle with a few pals from your other circles.
    func createCircle(name: String, emoji: String, activities: [String], memberIDs: Set<Friend.ID>) {
        var seen = Set<String>()
        let members = circles.flatMap(\.friends)
            .filter { memberIDs.contains($0.id) && seen.insert($0.name).inserted }
            .map { Friend(name: $0.name, color: $0.color, isActive: $0.isActive, doneToday: false) }
        let colors: [Color] = [.palsIndigo, .palsPink, .palsBlue]
        circles.append(PalsCircle(name: name, emoji: emoji, color: colors[circles.count % colors.count],
                                  pool: activities.map(CircleActivity.suggestion), streak: 0, friends: members))
    }

    /// Everyone you know, once each (for picking members of a new circle).
    var allPals: [Friend] {
        var seen = Set<String>()
        return circles.flatMap(\.friends).filter { seen.insert($0.name).inserted }
    }

    func friend(id: Friend.ID) -> Friend? {
        circles.lazy.flatMap(\.friends).first { $0.id == id }
    }

    // MARK: - Pranks

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
                ? "…just for fun. You already did yours today 😇"
                : "…because you haven't done today's \(selectedCircle.today.title.lowercased())."
        )
    }

    // MARK: - Demo helpers

    /// Undo today's activity and sent pranks so the flow can be shown again.
    func resetToday() {
        proofPhoto = nil
        doneCircles = []
        saveDoneCircles()
        let last = defaults.object(forKey: Self.lastCompletedKey) as? Date
        if last.map(Calendar.current.isDateInToday) ?? false {
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

    /// Mock circles get new IDs every launch, so today's progress is saved by name.
    private func saveDoneCircles() {
        let day = PalsDay.key(.now)
        let entries = circles.filter { doneCircles.contains($0.id) }.map { "\(day)|\($0.name)" }
        defaults.set(entries, forKey: Self.myDoneKey)
    }

    private func restoreDoneCircles() {
        let day = PalsDay.key(.now)
        for entry in defaults.stringArray(forKey: Self.myDoneKey) ?? [] {
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == day,
                  let circle = circles.first(where: { $0.name == parts[1] }) else { continue }
            doneCircles.insert(circle.id)
        }
    }
}

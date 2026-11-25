import Network
import Observation
import SwiftUI

struct Friend: Identifiable, Hashable {
    var id = UUID()
    let name: String
    let color: Color
    var isActive: Bool
    /// Did today's activity.
    var doneToday: Bool
    /// The prank you already sent them today (one per day).
    var prankedToday: PrankKind?
    /// Their iCloud user ID in Pals, for real (non-demo) pals.
    var cloudID: String? = nil
    /// Their profile photo, for real pals.
    var photo: UIImage? = nil
}

/// Something a circle can do on a day. Anyone in the circle can add one to the pool.
struct CircleActivity: Identifiable, Hashable {
    var id = UUID()
    var emoji: String
    var title: String
    /// Length of the timer; `nil` means there's no timer, you just mark it done.
    var minutes: Int?
    var addedBy: String = "Pals"
    /// Its CloudKit record, for activities in real circles.
    var cloudID: String? = nil
    /// You may edit or delete it: in real circles only the person who added it can.
    var canEdit = true
    /// Day it was added ("yyyy-MM-dd"), so it joins the daily draw from the next day.
    var addedOn: String? = nil

    /// What the daily draw knows a card by: the same on every phone and through edits.
    var drawKey: String { cloudID ?? title }

    var durationLabel: String {
        guard let minutes else { return "No timer" }
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    /// Ready-made ideas offered when creating a circle or adding an activity, grouped by category.
    static let suggestions: [CircleActivity] = ActivityCategory.allCases.flatMap(\.ideas)

    static func suggestion(_ title: String) -> CircleActivity {
        suggestions.first { $0.title == title } ?? CircleActivity(emoji: "✨", title: title, minutes: nil)
    }
}

/// Groups of ready-made activity ideas.
enum ActivityCategory: String, CaseIterable, Identifiable {
    case move = "Move", mind = "Mind", body = "Body", detox = "Detox", social = "Social", chill = "Chill"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .move: "🏃"
        case .mind: "🧠"
        case .body: "💧"
        case .detox: "📵"
        case .social: "💬"
        case .chill: "🌿"
        }
    }

    var color: Color {
        switch self {
        case .move: Color(hex: 0xFF5A36)
        case .mind: Color(hex: 0x7B5CFF)
        case .body: Color(hex: 0x14B8A6)
        case .detox: Color(hex: 0xFD3D9C)
        case .social: Color(hex: 0x2F80ED)
        case .chill: Color(hex: 0x22A06B)
        }
    }

    var ideas: [CircleActivity] {
        switch self {
        case .move: [
            CircleActivity(emoji: "🚶", title: "Walk for 5 minutes", minutes: 5),
            CircleActivity(emoji: "💪", title: "20 push-ups", minutes: nil),
            CircleActivity(emoji: "🤸", title: "Stretch 10 minutes", minutes: 10),
            CircleActivity(emoji: "🧎", title: "Plank for 1 minute", minutes: 1),
        ]
        case .mind: [
            CircleActivity(emoji: "📚", title: "Read 10 pages", minutes: nil),
            CircleActivity(emoji: "🧘", title: "Meditate 5 minutes", minutes: 5),
            CircleActivity(emoji: "✍️", title: "Write 3 lines in a journal", minutes: nil),
        ]
        case .body: [
            CircleActivity(emoji: "💧", title: "Drink 8 glasses of water", minutes: nil),
            CircleActivity(emoji: "🍎", title: "Eat a piece of fruit", minutes: nil),
            CircleActivity(emoji: "😴", title: "In bed before midnight", minutes: nil),
        ]
        case .detox: [
            CircleActivity(emoji: "📵", title: "No phone for 1 hour", minutes: 60),
            CircleActivity(emoji: "🙅", title: "No social media today", minutes: nil),
        ]
        case .social: [
            CircleActivity(emoji: "📞", title: "Call someone you miss", minutes: nil),
            CircleActivity(emoji: "💌", title: "Compliment a stranger", minutes: nil),
        ]
        case .chill: [
            CircleActivity(emoji: "🌳", title: "10 minutes outside", minutes: 10),
            CircleActivity(emoji: "🧹", title: "Tidy up for 10 minutes", minutes: 10),
        ]
        }
    }
}

struct PalsCircle: Identifiable, Hashable {
    var id = UUID()
    let name: String
    var emoji: String = "👯"
    var color: Color = .palsIndigo
    /// Every activity the circle has added. One of them is picked for everyone each day.
    var pool: [CircleActivity]
    /// Days in a row the whole circle has completed the activity.
    var streak: Int = 0
    var friends: [Friend]
    /// Invite code of a real circle in iCloud; `nil` for demo circles.
    var code: String? = nil

    /// Key for what's saved on this phone about the circle (today's draw, your moment…).
    var storageKey: String { code ?? name }

    /// The activity everyone in the circle does today.
    var today: CircleActivity { pick(for: .now) }

    /// Tomorrow's activity, shown ahead so people can plan for it.
    var tomorrow: CircleActivity {
        pick(for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)
    }

    /// Picks the day's activity from the pool, not the same as the day before.
    ///
    /// It's worked out from the circle's code and the date rather than chosen at random, so every
    /// member's phone lands on the same activity without a server deciding it. Each card gets a
    /// score for the day and the highest wins, so taking out or editing another card never
    /// changes the day's pick; a card added today joins the draw tomorrow.
    func pick(for date: Date) -> CircleActivity {
        let day = PalsDay.key(date)
        let settled = pool.filter { ($0.addedOn ?? "") < day }
        let cards = settled.isEmpty ? pool : settled
        guard cards.count > 1 else { return cards.first ?? CircleActivity.suggestions[0] }
        let yesterday = PalsDay.key(Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
        let yesterdays = winner(cards, day: yesterday)
        return winner(cards.filter { $0.drawKey != yesterdays.drawKey }, day: day)
    }

    private func winner(_ cards: [CircleActivity], day: String) -> CircleActivity {
        cards.max { score($0, day: day) < score($1, day: day) } ?? cards[0]
    }

    private func score(_ card: CircleActivity, day: String) -> UInt64 {
        // FNV-1a: stable across launches and devices (unlike `hashValue`).
        // Real circles use their invite code, which every member's phone shares.
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in "\(code ?? name)|\(day)|\(card.drawKey)".utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return hash
    }
}

enum PalsDay {
    /// "2026-11-23" in the user's time zone.
    static func key(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// State behind the home screen. Circles come from iCloud (CloudKit public database) once
/// you're in at least one real circle; until then, and without iCloud, demo circles stand in.
@Observable
final class HomeModel {
    private(set) var circles: [PalsCircle]
    var selectedCircleID: PalsCircle.ID {
        didSet { defaults.set(selectedCircle.storageKey, forKey: Self.selectedKey) }
    }

    /// Showing the built-in demo circles rather than real ones.
    private(set) var isDemo = true
    private(set) var cloudStatus: CloudStatus = .unknown
    /// A background sync problem, shown as a banner until a sync works again.
    var syncIssue: PalsError?
    /// A sync with iCloud is running.
    private(set) var isSyncing = false
    private(set) var isOnline = true

    enum CloudStatus: Equatable { case unknown, signedOut, ready, failed }

    @ObservationIgnored let cloud = CloudStore()
    @ObservationIgnored private var myUserID: String?
    /// Stable local IDs for real circles (by code) and pals (by iCloud user ID) across refreshes.
    @ObservationIgnored private var circleIDs: [String: UUID] = [:]
    @ObservationIgnored private var friendIDs: [String: UUID] = [:]
    /// …and for activities, by record name.
    @ObservationIgnored private var activityIDs: [String: UUID] = [:]
    @ObservationIgnored private var touchedMembership = false
    /// The sync in flight, so overlapping requests share it.
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    /// Extra looks a few seconds after a change, once iCloud's queries have caught up.
    @ObservationIgnored private var followUpTask: Task<Void, Never>?
    /// Writes that failed because we were offline; sent again once we're back.
    @ObservationIgnored private var pendingWrites: [CloudWrite] = []
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    /// Circle codes the push subscriptions were last set up for (`nil`: not yet this launch).
    @ObservationIgnored private var subscribedCodes: Set<String>?
    /// Things you just did that iCloud's queries may not show for a few seconds, kept on
    /// screen until they do: activities you added and pranks you sent, by circle code.
    @ObservationIgnored private var recentActivities: [String: [(activity: CircleActivity, at: Date)]] = [:]
    /// Activities you edited or deleted, by record name, until queries catch up.
    @ObservationIgnored private var recentActivityEdits: [String: (activity: CircleActivity, at: Date)] = [:]
    @ObservationIgnored private var recentActivityDeletes: [String: Date] = [:]
    /// ["<code>|<day>": [pal's user ID: prank]]
    @ObservationIgnored private var recentPranks: [String: [String: PrankKind]] = [:]

    typealias CloudWrite = (CloudStore) async throws -> Void

    /// The activity whose session (timer / proof) is open.
    var activeActivity: CircleActivity?
    /// A prank waiting to be played on screen.
    var incomingPrank: IncomingPrank?
    /// Your proof for today, per circle. Posting one unlocks that circle's proofs.
    private(set) var myProofs: [PalsCircle.ID: DualProof] = [:]
    /// Demo proofs for pals who are done today, until they come from a backend.
    @ObservationIgnored private var palProofs: [Friend.ID: DualProof] = [:]

    private(set) var streakDays: Int
    private(set) var freezes: Int = 2
    /// Circles where you've done today's activity.
    private(set) var doneCircles: Set<PalsCircle.ID> = []
    /// Circles where you've drawn (flipped) today's card.
    private(set) var revealedCircles: Set<PalsCircle.ID> = []
    /// Bumped to ask the home screen to play the card draw (e.g. from the activity bar).
    var drawRequests = 0

    private let defaults = UserDefaults.standard
    private static let streakKey = "streakDays"
    private static let lastCompletedKey = "lastCompletedDate"
    private static let myDoneKey = "myDoneToday"      // ["<day>|<circle name>"]
    private static let revealedKey = "revealedToday"  // ["<day>|<circle name>"]
    private static let selectedKey = "selectedCircle"
    private static let seenPranksKey = "seenPrankIDs"
    private static let knownCodesKey = "myCircleCodes"

    /// Codes of circles this device created or joined (see `CloudStore.fetchMyCircles`).
    private var knownCodes: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.knownCodesKey) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.knownCodesKey) }
    }

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
        revealedCircles = restore(Self.revealedKey)
        restoreProofs()
    }

    /// Demo circles only: a pal "pranks" you when you open the app without having done
    /// today's activity, so the prank flow can be shown without a second phone.
    func playDemoLaunchPrank() {
        guard isDemo, !completedToday, let pranker = selectedCircle.friends.last else { return }
        incomingPrank = IncomingPrank(
            kind: PrankKind.allCases.randomElement() ?? .slap,
            fromName: pranker.name,
            fromColor: pranker.color
        )
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

    /// Opens today's activity in the circle on your orbit, or plays the card draw if it isn't drawn yet.
    func startActivity() {
        guard isRevealed(selectedCircle) else {
            drawRequests += 1
            return
        }
        activeActivity = selectedCircle.today
    }

    // MARK: - Today's card

    /// Drawn today (doing the activity counts too).
    func isRevealed(_ circle: PalsCircle) -> Bool {
        revealedCircles.contains(circle.id) || doneCircles.contains(circle.id)
    }

    /// Marks today's card as drawn for this circle (it stays face up for the rest of the day).
    func reveal(_ circle: PalsCircle) {
        revealedCircles.insert(circle.id)
        save(revealedCircles, to: Self.revealedKey)
    }

    func completeTodayActivity(in circleID: PalsCircle.ID? = nil) {
        let circleID = circleID ?? selectedCircleID
        let wasDone = doneCircles.contains(circleID)
        doneCircles.insert(circleID)
        saveDoneCircles()
        if !wasDone, let code = circle(id: circleID)?.code {
            push { try await $0.markDone(code: code, day: PalsDay.key(.now)) }
        }
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
        activity.addedOn = PalsDay.key(.now)
        let code = circles[index].code
        let id = UUID()
        if let code {
            let recordName = CloudStore.activityRecordName(code: code, id: id)
            activity.cloudID = recordName
            activityIDs[recordName] = activity.id
        }
        circles[index].pool.append(activity)
        if let code {
            let name = myName
            recentActivities[code, default: []].append((activity, .now))
            push { try await $0.addActivity(activity, code: code, addedBy: name, id: id) }
        }
    }

    /// Changes an activity's emoji, title and timer, for everyone in the circle.
    func updateActivity(_ activity: CircleActivity, emoji: String, title: String, minutes: Int?,
                        in circleID: PalsCircle.ID) {
        guard activity.canEdit, let c = circles.firstIndex(where: { $0.id == circleID }),
              let a = circles[c].pool.firstIndex(where: { $0.id == activity.id }) else { return }
        circles[c].pool[a].emoji = emoji
        circles[c].pool[a].title = title
        circles[c].pool[a].minutes = minutes
        guard let code = circles[c].code, let recordName = activity.cloudID else { return }
        let edited = circles[c].pool[a]
        recentActivityEdits[recordName] = (edited, .now)
        if let i = recentActivities[code]?.firstIndex(where: { $0.activity.cloudID == recordName }) {
            recentActivities[code]?[i].activity = edited
        }
        push { try await $0.updateActivity(recordName: recordName, emoji: emoji, title: title, minutes: minutes) }
    }

    /// Takes an activity out of the pool for everyone. A circle keeps at least one.
    func deleteActivity(_ activity: CircleActivity, in circleID: PalsCircle.ID) {
        guard activity.canEdit, let c = circles.firstIndex(where: { $0.id == circleID }),
              circles[c].pool.count > 1 else { return }
        circles[c].pool.removeAll { $0.id == activity.id }
        guard let code = circles[c].code, let recordName = activity.cloudID else { return }
        recentActivityDeletes[recordName] = .now
        recentActivities[code]?.removeAll { $0.activity.cloudID == recordName }
        push { try await $0.deleteActivity(recordName: recordName) }
    }

    // MARK: - Circles

    /// Demo: creates a circle with a few pals from your other circles.
    private func createDemoCircle(name: String, emoji: String, activities: [String], memberIDs: Set<Friend.ID>) {
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

    func sendPrank(_ kind: PrankKind, to friendID: Friend.ID, in circleID: PalsCircle.ID? = nil) {
        let circleID = circleID ?? selectedCircleID
        for c in circles.indices where isDemo || circles[c].id == circleID {
            for f in circles[c].friends.indices where circles[c].friends[f].id == friendID {
                circles[c].friends[f].prankedToday = kind
                if let code = circles[c].code, let to = circles[c].friends[f].cloudID {
                    recentPranks["\(code)|\(PalsDay.key(.now))", default: [:]][to] = kind
                    push { try await $0.sendPrank(kind, to: to, code: code, day: PalsDay.key(.now)) }
                }
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
        guard isDemo else {
            Task { await refresh() }
            return
        }
        let pals = selectedCircle.friends
        let pranker = pals.filter(\.doneToday).randomElement() ?? pals.randomElement()
        guard let pranker else { return }
        incomingPrank = IncomingPrank(
            kind: PrankKind.allCases.randomElement() ?? .slap,
            fromName: pranker.name,
            fromColor: pranker.color,
            reason: completedToday
                ? "…just for fun. You already did yours today 😇"
                : (isRevealed(selectedCircle)
                    ? "…because you haven't done today's \(selectedCircle.today.title.lowercased())."
                    : "…because you haven't even drawn today's card.")
        )
    }

    // MARK: - Proofs

    func myProof(in circle: PalsCircle) -> DualProof? { myProofs[circle.id] }

    /// Takes allowed per circle per day: the first moment plus two retakes.
    static let momentTries = 3
    private static let momentTriesKey = "momentTriesUsed" // ["<day>|<circle name>": count]

    func momentTriesLeft(in circle: PalsCircle) -> Int {
        _ = triesVersion // observed, so views update after a take
        let used = (defaults.dictionary(forKey: Self.momentTriesKey) as? [String: Int])?[triesKey(circle)] ?? 0
        return max(0, Self.momentTries - used)
    }

    /// Counts one take (back photo + selfie) against today's tries.
    func useMomentTry(in circleID: PalsCircle.ID) {
        guard let circle = circle(id: circleID) else { return }
        let today = PalsDay.key(.now)
        // Keep only today's counts.
        var used = (defaults.dictionary(forKey: Self.momentTriesKey) as? [String: Int] ?? [:])
            .filter { $0.key.hasPrefix(today) }
        used[triesKey(circle), default: 0] += 1
        defaults.set(used, forKey: Self.momentTriesKey)
        triesVersion += 1
    }

    /// Bumped when tries change, so views reading `momentTriesLeft` refresh.
    private(set) var triesVersion = 0

    private func triesKey(_ circle: PalsCircle) -> String { "\(PalsDay.key(.now))|\(circle.storageKey)" }

    /// Everyone's proof for today in this circle: yours first, then the newest.
    func proofs(in circle: PalsCircle) -> [DualProof] {
        let pals = circle.friends.filter(\.doneToday).compactMap { palProofs[$0.id] }
            .sorted { $0.time > $1.time }
        return (myProofs[circle.id].map { [$0] } ?? []) + pals
    }

    /// Posting a proof also counts as doing today's activity.
    func postProof(_ proof: DualProof, in circleID: PalsCircle.ID? = nil) {
        let circleID = circleID ?? selectedCircleID
        guard let circle = circle(id: circleID) else { return }
        myProofs[circleID] = proof
        ProofStore.save(proof, circle: circle.storageKey)
        if let code = circle.code {
            // Marks you done in the cloud too (moment + done in one save).
            doneCircles.insert(circleID)
            saveDoneCircles()
            push { try await $0.postMoment(code: code, day: PalsDay.key(.now), back: proof.back, front: proof.front) }
        }
        if !isDone(in: circle) { completeTodayActivity(in: circleID) }
        else { bumpStreakIfFirstToday() }
    }

    /// The streak grows once a day, the first time you finish any circle's activity.
    private func bumpStreakIfFirstToday() {
        let last = defaults.object(forKey: Self.lastCompletedKey) as? Date
        guard !(last.map(Calendar.current.isDateInToday) ?? false) else { return }
        streakDays += 1
        defaults.set(streakDays, forKey: Self.streakKey)
        defaults.set(Date(), forKey: Self.lastCompletedKey)
    }

    private func restoreProofs() {
        let me = defaults.string(forKey: "profileName") ?? "You"
        for circle in circles {
            if let proof = ProofStore.load(circle: circle.storageKey, author: me) {
                myProofs[circle.id] = proof
            }
            for (index, friend) in circle.friends.filter(\.doneToday).enumerated() {
                palProofs[friend.id] = DemoProofArt.make(for: circle.today, author: friend.name,
                                                         color: friend.color, minutesAgo: 25 + index * 47,
                                                         variant: [2, 3, 1][index % 3])
            }
        }
    }

    // MARK: - iCloud

    private var myName: String {
        let name = defaults.string(forKey: "profileName") ?? ""
        return name.isEmpty ? "Pal" : name
    }

    private var myProfile: MemberProfile { MemberProfile(name: myName, photo: ProfilePhotoStore.load()) }

    /// You can make and join real circles (signed in to iCloud).
    var canUseCloud: Bool { cloudStatus == .ready }

    /// Pulls your real circles from iCloud. With none (or no iCloud), the demo circles stay.
    /// Overlapping calls (pull to refresh, the timer, a push) share one sync.
    func refresh() async {
        if let running = refreshTask {
            await running.value
            return
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        guard await cloud.isAvailable() else {
            cloudStatus = .signedOut
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        do {
            let me = try await cloud.userID()
            myUserID = me
            cloudStatus = .ready
            let (fetched, gone) = try await cloud.fetchMyCircles(known: knownCodes)
            knownCodes = knownCodes.union(fetched.map(\.code)).subtracting(gone)
            if !touchedMembership {
                touchedMembership = true
                // Once per launch: your current name/photo and "active now" in every circle,
                // and yesterday-and-older moments cleared out.
                let profile = myProfile
                for circle in fetched {
                    push { try await $0.saveMember(code: circle.code, me: profile) }
                }
                push { try await $0.deleteOldMoments() }
            }
            apply(fetched, me: me)
            syncSubscriptionsIfNeeded(fetched)
            if syncIssue != nil { syncIssue = nil }
            flushPendingWrites()
        } catch {
            guard let issue = PalsError.from(error) else { return }
            if cloudStatus == .unknown { cloudStatus = .failed }
            syncIssue = issue
        }
    }

    /// Sets up push subscriptions when your circles change (and once per launch). Optional: if it
    /// fails, the regular refresh still keeps things current, so it's only logged and retried later.
    private func syncSubscriptionsIfNeeded(_ circles: [CloudCircle]) {
        let codes = Set(circles.map(\.code))
        guard !codes.isEmpty, codes != subscribedCodes else { return }
        subscribedCodes = codes
        let list = circles.map { (code: $0.code, name: $0.name) }
        Task {
            do {
                try await cloud.syncSubscriptions(circles: list)
            } catch {
                subscribedCodes = nil
                PalsError.logOnly(error, context: "syncing push subscriptions")
            }
        }
    }

    /// iCloud's queries show a change a few seconds after it's saved: look again shortly after one.
    private func refreshAfterChange() {
        followUpTask?.cancel()
        followUpTask = Task {
            for delay in [2.0, 6.0] {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    /// Watches the connection: going offline shows the banner, coming back sends what waited.
    func startMonitoringNetwork() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "pals.network"))
        pathMonitor = monitor
    }

    private func networkChanged(online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        // Only worth a banner once there are real circles to keep in sync.
        guard !isDemo else { return }
        if online {
            if syncIssue?.kind == .offline { syncIssue = nil }
            Task { await refresh() } // also sends the writes that waited
        } else {
            syncIssue = .offline
        }
    }

    /// The banner's "Try again".
    func retrySync() {
        syncIssue = nil
        Task { await refresh() }
    }

    /// Your name or photo changed: update it in every real circle.
    func profileChanged() {
        let profile = myProfile
        for code in circles.compactMap(\.code) {
            push { try await $0.saveMember(code: code, me: profile) }
        }
    }

    /// Creates a real circle in iCloud, or a demo one without iCloud. Returns the invite code
    /// (`nil` for a demo circle); throws a `PalsError` if iCloud couldn't make it.
    @discardableResult
    func createCircle(name: String, emoji: String, activities: [String],
                      memberIDs: Set<Friend.ID>) async throws -> String? {
        if cloudStatus != .ready && cloudStatus != .signedOut { await refresh() }
        guard canUseCloud else {
            if cloudStatus == .signedOut {
                createDemoCircle(name: name, emoji: emoji, activities: activities, memberIDs: memberIDs)
                return nil
            }
            throw syncIssue ?? .unknown
        }
        let colorIndex = isDemo ? 0 : circles.count % 3
        let code: String
        do {
            code = try await cloud.createCircle(name: name, emoji: emoji, colorIndex: colorIndex,
                                                activities: activities.map(CircleActivity.suggestion),
                                                me: myProfile)
        } catch {
            throw PalsError.from(error) ?? .unknown
        }
        knownCodes.insert(code)
        defaults.set(code, forKey: Self.selectedKey)
        await refresh()
        refreshAfterChange()
        Task { await PushNotifications.askPermissionIfNeeded() }
        return code
    }

    /// Joins a real circle by its invite code. Returns what went wrong, or `nil` on success.
    func joinCircle(code: String) async -> String? {
        if cloudStatus != .ready && cloudStatus != .signedOut { await refresh() }
        guard canUseCloud else {
            return cloudStatus == .signedOut
                ? "Sign in to iCloud in Settings to join a circle."
                : (syncIssue ?? .unknown).message
        }
        let code = CloudStore.normalized(code)
        guard code.count == 8 else { return "Invite codes have 8 letters and numbers." }
        do {
            guard try await cloud.join(code: code, me: myProfile) else {
                return "No circle has that code. Check it with your pal."
            }
        } catch {
            return (PalsError.from(error) ?? .unknown).message
        }
        knownCodes.insert(code)
        defaults.set(code, forKey: Self.selectedKey)
        await refresh()
        refreshAfterChange()
        Task { await PushNotifications.askPermissionIfNeeded() }
        return nil
    }

    /// Sends a change to iCloud in the background. Network blips and a busy iCloud are retried
    /// with a growing pause; offline changes wait for the connection; anything else shows the
    /// sync banner. Every write is an upsert to a fixed record name, so sending one twice is safe.
    private func push(_ write: @escaping CloudWrite) {
        Task { await send(write) }
    }

    private func send(_ write: @escaping CloudWrite, attempt: Int = 1) async {
        do {
            try await write(cloud)
            if syncIssue?.isTransient == true { syncIssue = nil }
            refreshAfterChange()
        } catch {
            guard let issue = PalsError.from(error) else { return }
            if issue.kind == .offline {
                pendingWrites.append(write)
                syncIssue = issue
            } else if issue.isTransient && attempt < 4 {
                try? await Task.sleep(for: .seconds(issue.retryAfter ?? pow(2, Double(attempt))))
                await send(write, attempt: attempt + 1)
            } else {
                syncIssue = issue
            }
        }
    }

    private func flushPendingWrites() {
        guard !pendingWrites.isEmpty else { return }
        let writes = pendingWrites
        pendingWrites = []
        for write in writes { push(write) }
    }

    /// Replaces the circles with what's in iCloud, keeping local IDs and today's state.
    private func apply(_ fetched: [CloudCircle], me: String) {
        guard !fetched.isEmpty else { return }
        let today = PalsDay.key(.now)
        let palette: [Color] = [.palsIndigo, .palsPink, .palsBlue]

        var mapped: [PalsCircle] = []
        var cloudDone = Set<PalsCircle.ID>()
        var mine: [PalsCircle.ID: DualProof] = [:]
        var pals: [Friend.ID: DualProof] = [:]
        var incoming: [(CloudPrank, CloudMember?)] = []

        for remote in fetched {
            let id = circleIDs[remote.code] ?? UUID()
            circleIDs[remote.code] = id
            let doneToday = remote.done[today] ?? []
            let sentToday = recentPranks["\(remote.code)|\(today)"] ?? [:]
            // Activities you added that the query doesn't show yet (forgotten after 5 minutes).
            let shown = Set(remote.activities.map(\.recordName))
            recentActivities[remote.code] = recentActivities[remote.code]?
                .filter { !shown.contains($0.activity.cloudID ?? "") && Date.now.timeIntervalSince($0.at) < 5 * 60 }
            let unseen = recentActivities[remote.code]?.map(\.activity) ?? []
            // Your recent edits and deletes win over a query that hasn't caught up (for 2 minutes).
            recentActivityEdits = recentActivityEdits.filter { Date.now.timeIntervalSince($0.value.at) < 2 * 60 }
            recentActivityDeletes = recentActivityDeletes.filter { Date.now.timeIntervalSince($0.value) < 2 * 60 }
            let pool: [CircleActivity] = remote.activities
                .filter { recentActivityDeletes[$0.recordName] == nil }
                .map { cloud in
                    var activity = recentActivityEdits[cloud.recordName]?.activity
                        ?? CircleActivity(emoji: cloud.emoji, title: cloud.title, minutes: cloud.minutes,
                                          addedBy: cloud.addedBy, cloudID: cloud.recordName, canEdit: cloud.isMine,
                                          addedOn: cloud.createdAt.map { PalsDay.key($0) })
                    // Same ID on every refresh, so a sheet open on it keeps working.
                    activity.id = activityIDs[cloud.recordName] ?? activity.id
                    activityIDs[cloud.recordName] = activity.id
                    return activity
                }

            let friends: [Friend] = remote.members.filter { $0.userID != me }.map { member in
                let friendID = friendIDs[member.userID] ?? UUID()
                friendIDs[member.userID] = friendID
                return Friend(
                    id: friendID,
                    name: member.name,
                    color: palette[Self.stableHash(member.userID) % palette.count],
                    isActive: member.lastActive.map { Date.now.timeIntervalSince($0) < 10 * 60 } ?? false,
                    doneToday: doneToday.contains(member.userID),
                    prankedToday: remote.pranks.first { $0.fromID == me && $0.toID == member.userID }?.kind
                        ?? sentToday[member.userID],
                    cloudID: member.userID,
                    photo: member.avatar
                )
            }

            var circle = PalsCircle(
                name: remote.name, emoji: remote.emoji, color: palette[remote.colorIndex % palette.count],
                pool: pool + unseen,
                streak: Self.streak(remote.done, members: Set(remote.members.map(\.userID))),
                friends: friends,
                code: remote.code
            )
            circle.id = id
            mapped.append(circle)

            if doneToday.contains(me) { cloudDone.insert(id) }
            for moment in remote.moments {
                if moment.userID == me {
                    mine[id] = DualProof(back: moment.back, front: moment.front, author: myName,
                                         time: moment.postedAt, isYours: true)
                } else if let friend = friends.first(where: { $0.cloudID == moment.userID }) {
                    pals[friend.id] = DualProof(back: moment.back, front: moment.front, author: friend.name,
                                                authorColor: friend.color, time: moment.postedAt,
                                                authorPhoto: friend.photo)
                }
            }
            for prank in remote.pranks where prank.toID == me {
                incoming.append((prank, remote.members.first { $0.userID == prank.fromID }))
            }
        }

        let wasDemo = isDemo
        circles = mapped
        isDemo = false
        if wasDemo || circle(id: selectedCircleID) == nil {
            let saved = defaults.string(forKey: Self.selectedKey)
            selectedCircleID = mapped.first { $0.storageKey == saved }?.id ?? mapped[0].id
        }
        // Done = what iCloud says, plus anything you just did that's still on its way up.
        doneCircles = cloudDone.union(doneCircles.filter { id in mapped.contains { $0.id == id } })
        revealedCircles = restore(Self.revealedKey)
        myProofs = myProofs.filter { id, _ in mapped.contains { $0.id == id } }.merging(mine) { _, remote in remote }
        palProofs = pals

        // Play the first prank you haven't seen yet.
        var seen = Set(defaults.stringArray(forKey: Self.seenPranksKey) ?? [])
        if incomingPrank == nil, let (prank, from) = incoming.first(where: { !seen.contains($0.0.id) }) {
            seen.insert(prank.id)
            defaults.set(Array(seen), forKey: Self.seenPranksKey)
            incomingPrank = IncomingPrank(kind: prank.kind, fromName: from?.name ?? "A pal",
                                          fromColor: .palsPink)
        }
    }

    /// Same number on every launch and device (unlike `hashValue`), for a pal's color.
    static func stableHash(_ text: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return Int(hash % 1_000_003)
    }

    /// Days in a row (up to today) on which everyone in the circle was done.
    /// Today only counts once it's complete; until then the streak runs to yesterday.
    static func streak(_ done: [String: Set<String>], members: Set<String>) -> Int {
        guard !members.isEmpty else { return 0 }
        let calendar = Calendar.current
        var day = Date.now
        var count = 0
        if members.isSubset(of: done[PalsDay.key(day)] ?? []) { count += 1 }
        for _ in 0..<365 {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            guard members.isSubset(of: done[PalsDay.key(day)] ?? []) else { break }
            count += 1
        }
        return count
    }

    // MARK: - Demo helpers

    /// Undo today's activity and sent pranks so the flow can be shown again.
    func resetToday() {
        for circle in circles { ProofStore.delete(circle: circle.storageKey) }
        myProofs = [:]
        defaults.removeObject(forKey: Self.momentTriesKey)
        triesVersion += 1
        doneCircles = []
        saveDoneCircles()
        revealedCircles = []
        save(revealedCircles, to: Self.revealedKey)
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
        let entries = circles.filter { doneCircles.contains($0.id) }.map { "\(day)|\($0.storageKey)" }
        defaults.set(entries, forKey: Self.myDoneKey)
    }

    private func save(_ ids: Set<PalsCircle.ID>, to key: String) {
        let day = PalsDay.key(.now)
        defaults.set(circles.filter { ids.contains($0.id) }.map { "\(day)|\($0.storageKey)" }, forKey: key)
    }

    private func restore(_ key: String) -> Set<PalsCircle.ID> {
        let day = PalsDay.key(.now)
        var ids = Set<PalsCircle.ID>()
        for entry in defaults.stringArray(forKey: key) ?? [] {
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == day,
                  let circle = circles.first(where: { $0.storageKey == parts[1] }) else { continue }
            ids.insert(circle.id)
        }
        return ids
    }

    private func restoreDoneCircles() {
        let day = PalsDay.key(.now)
        for entry in defaults.stringArray(forKey: Self.myDoneKey) ?? [] {
            let parts = entry.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == day,
                  let circle = circles.first(where: { $0.storageKey == parts[1] }) else { continue }
            doneCircles.insert(circle.id)
        }
    }
}

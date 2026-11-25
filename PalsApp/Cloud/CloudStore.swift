import CloudKit
import UIKit

/// Pals' data lives in the CloudKit **public** database, so it counts against the app's quota,
/// never the user's iCloud storage. Nothing is browsable: every record carries its circle's
/// random invite code, and the app only ever asks for records by that code. Knowing a circle's
/// code is what lets you in.
///
/// Record types (record names are deterministic, so "once per day" holds by construction and
/// writes can be blind upserts):
///
/// - `Circle`   `circle-<code>`                      name, emoji, colorIndex, ownerID
/// - `Member`   `member-<code>-<user>`               circleID, userID, name, avatar (asset), lastActive
/// - `Activity` `activity-<code>-<uuid>`             circleID, emoji, title, minutes, addedBy, createdAt
/// - `Done`     `done-<code>-<user>-<day>`           circleID, userID, day
/// - `Moment`   `moment-<code>-<user>-<day>`         circleID, userID, day, back, front (assets), postedAt
/// - `Prank`    `prank-<code>-<from>-<to>-<day>`     circleID, fromID, toID, kind, day
///
/// The public database's default roles fit: anyone signed in to iCloud can create, only a
/// record's creator can change or delete it, and everyone can read.
///
/// Queryable indexes to add in CloudKit Console (Development, then deploy to Production):
/// Member.circleID, Member.userID, Activity.circleID, Done.circleID,
/// Moment.circleID, Moment.userID, Moment.day, Prank.circleID, Prank.day,
/// and recordName on every type. The record types themselves appear in Development the
/// first time the app saves one (create a circle once, then add the indexes).
@MainActor
final class CloudStore {
    static let containerID = "iCloud.com.ahmetkasimnazli.PalsApp"

    private let container = CKContainer(identifier: CloudStore.containerID)
    private var db: CKDatabase { container.publicCloudDatabase }
    private var cachedUserID: String?

    enum RecordType {
        static let circle = "Circle", member = "Member", activity = "Activity"
        static let done = "Done", moment = "Moment", prank = "Prank"
    }

    // MARK: - Account

    /// Signed in to iCloud (needed to write; the public database can't be written anonymously).
    func isAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// A stable, opaque ID for this iCloud user in Pals' container.
    func userID() async throws -> String {
        if let cachedUserID { return cachedUserID }
        let id = try await container.userRecordID().recordName
        cachedUserID = id
        return id
    }

    // MARK: - Reading

    /// Every circle you're a member of, with today's state, plus `known` circles (ones this
    /// device created or joined). Queries only see a new record a few seconds after it's saved,
    /// so a circle you just joined may be missing from the membership query; fetching it by code
    /// always works. `gone` lists known codes whose circle no longer exists.
    func fetchMyCircles(known: Set<String> = []) async throws -> (circles: [CloudCircle], gone: Set<String>) {
        let me = try await userID()
        let memberships = try await query(RecordType.member, NSPredicate(format: "userID == %@", me))
        let codes = Set(memberships.compactMap { $0["circleID"] as? String }).union(known)

        var circles: [CloudCircle] = []
        var gone = Set<String>()
        try await withThrowingTaskGroup(of: (String, CloudCircle?).self) { group in
            for code in codes {
                group.addTask { (code, try await self.fetchCircle(code: code)) }
            }
            for try await (code, circle) in group {
                if let circle { circles.append(circle) } else { gone.insert(code) }
            }
        }
        return (circles.sorted { $0.code < $1.code }, gone)
    }

    /// One circle by invite code, or `nil` if there's no such circle.
    func fetchCircle(code: String) async throws -> CloudCircle? {
        let circleRecord: CKRecord
        do {
            circleRecord = try await db.record(for: CKRecord.ID(recordName: "circle-\(code)"))
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }

        let byCircle = NSPredicate(format: "circleID == %@", code)
        let today = PalsDay.key(.now)
        async let members = query(RecordType.member, byCircle)
        async let activities = query(RecordType.activity, byCircle)
        async let done = query(RecordType.done, byCircle)
        async let moments = query(RecordType.moment, NSPredicate(format: "circleID == %@ AND day == %@", code, today))
        async let pranks = query(RecordType.prank, NSPredicate(format: "circleID == %@ AND day == %@", code, today))

        return CloudCircle(
            code: code,
            name: circleRecord["name"] as? String ?? "Circle",
            emoji: circleRecord["emoji"] as? String ?? "👯",
            colorIndex: circleRecord["colorIndex"] as? Int ?? 0,
            ownerID: circleRecord["ownerID"] as? String ?? "",
            members: try await members.map { record in
                CloudMember(userID: record["userID"] as? String ?? "",
                            name: record["name"] as? String ?? "Pal",
                            avatar: Self.image(record["avatar"]),
                            lastActive: record["lastActive"] as? Date)
            },
            activities: try await activities
                .sorted { ($0["createdAt"] as? Date ?? .distantPast) < ($1["createdAt"] as? Date ?? .distantPast) }
                .map { record in
                    CloudActivity(recordName: record.recordID.recordName,
                                  emoji: record["emoji"] as? String ?? "✨",
                                  title: record["title"] as? String ?? "Something",
                                  minutes: record["minutes"] as? Int,
                                  addedBy: record["addedBy"] as? String ?? "Pals",
                                  createdAt: record["createdAt"] as? Date,
                                  // Only the person who added an activity can change it (public DB roles).
                                  isMine: Self.isMine(record, me: cachedUserID))
                },
            done: try await done.reduce(into: [String: Set<String>]()) { result, record in
                guard let day = record["day"] as? String, let user = record["userID"] as? String else { return }
                result[day, default: []].insert(user)
            },
            moments: try await moments.compactMap { record in
                guard let back = Self.image(record["back"]), let front = Self.image(record["front"]) else { return nil }
                return CloudMoment(userID: record["userID"] as? String ?? "", back: back, front: front,
                                   postedAt: record["postedAt"] as? Date ?? .now)
            },
            pranks: try await pranks.compactMap { record in
                guard let kind = (record["kind"] as? String).flatMap(PrankKind.init(rawValue:)) else { return nil }
                return CloudPrank(id: record.recordID.recordName,
                                  fromID: record["fromID"] as? String ?? "",
                                  toID: record["toID"] as? String ?? "",
                                  kind: kind)
            }
        )
    }

    // MARK: - Writing

    /// Creates a circle with its first activities and you as its first member. Returns the invite code.
    func createCircle(name: String, emoji: String, colorIndex: Int,
                      activities: [CircleActivity], me: MemberProfile) async throws -> String {
        let userID = try await userID()
        let code = Self.newCode()
        let circle = CKRecord(recordType: RecordType.circle, recordID: CKRecord.ID(recordName: "circle-\(code)"))
        circle["name"] = name
        circle["emoji"] = emoji
        circle["colorIndex"] = colorIndex
        circle["ownerID"] = userID

        var records = [circle, memberRecord(code: code, userID: userID, me: me)]
        for (offset, activity) in activities.enumerated() {
            records.append(activityRecord(code: code, activity: activity, addedBy: me.name,
                                          createdAt: Date.now.addingTimeInterval(Double(offset))))
        }
        try await save(records)
        return code
    }

    /// Joins the circle with this invite code. Returns `nil` if the code doesn't exist.
    func join(code: String, me: MemberProfile) async throws -> Bool {
        let code = Self.normalized(code)
        do {
            _ = try await db.record(for: CKRecord.ID(recordName: "circle-\(code)"))
        } catch let error as CKError where error.code == .unknownItem {
            return false
        }
        try await save([memberRecord(code: code, userID: try await userID(), me: me)])
        return true
    }

    /// Updates your name, photo and "last active" in a circle.
    func saveMember(code: String, me: MemberProfile) async throws {
        try await save([memberRecord(code: code, userID: try await userID(), me: me)])
    }

    /// Leaves a circle (deletes your membership; your old records stay until they expire).
    func leave(code: String) async throws {
        let id = CKRecord.ID(recordName: "member-\(code)-\(try await userID())")
        _ = try await db.modifyRecords(saving: [], deleting: [id])
    }

    /// `id` is chosen by the caller once, so retrying the same add never makes a duplicate.
    func addActivity(_ activity: CircleActivity, code: String, addedBy: String, id: UUID) async throws {
        try await save([activityRecord(code: code, activity: activity, addedBy: addedBy, createdAt: .now, id: id)])
    }

    /// The record name `addActivity` uses for an activity, so it can be edited or deleted later.
    static func activityRecordName(code: String, id: UUID) -> String { "activity-\(code)-\(id.uuidString)" }

    /// Changes an activity's emoji, title and timer, keeping who added it and when.
    func updateActivity(recordName: String, emoji: String, title: String, minutes: Int?) async throws {
        let record = try await db.record(for: CKRecord.ID(recordName: recordName))
        record["emoji"] = emoji
        record["title"] = title
        record["minutes"] = minutes
        let result = try await db.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
        for (_, outcome) in result.saveResults {
            if case .failure(let error) = outcome { throw error }
        }
    }

    /// Removes an activity from the pool. Already gone counts as done.
    func deleteActivity(recordName: String) async throws {
        let result = try await db.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: recordName)])
        for (_, outcome) in result.deleteResults {
            if case .failure(let error) = outcome {
                if (error as? CKError)?.code == .unknownItem { continue }
                throw error
            }
        }
    }

    func markDone(code: String, day: String) async throws {
        let userID = try await userID()
        let record = CKRecord(recordType: RecordType.done,
                              recordID: CKRecord.ID(recordName: "done-\(code)-\(userID)-\(day)"))
        record["circleID"] = code
        record["userID"] = userID
        record["day"] = day
        try await save([record])
    }

    /// Posts your moment for the day (replacing an earlier take) and marks you done.
    func postMoment(code: String, day: String, back: UIImage, front: UIImage) async throws {
        let userID = try await userID()
        let record = CKRecord(recordType: RecordType.moment,
                              recordID: CKRecord.ID(recordName: "moment-\(code)-\(userID)-\(day)"))
        record["circleID"] = code
        record["userID"] = userID
        record["day"] = day
        record["postedAt"] = Date.now
        record["back"] = Self.asset(back, maxSide: 1400)
        record["front"] = Self.asset(front, maxSide: 900)

        let done = CKRecord(recordType: RecordType.done,
                            recordID: CKRecord.ID(recordName: "done-\(code)-\(userID)-\(day)"))
        done["circleID"] = code
        done["userID"] = userID
        done["day"] = day
        try await save([record, done])
    }

    func sendPrank(_ kind: PrankKind, to friendID: String, code: String, day: String) async throws {
        let userID = try await userID()
        let record = CKRecord(recordType: RecordType.prank,
                              recordID: CKRecord.ID(recordName: "prank-\(code)-\(userID)-\(friendID)-\(day)"))
        record["circleID"] = code
        record["fromID"] = userID
        record["toID"] = friendID
        record["kind"] = kind.rawValue
        record["day"] = day
        try await save([record])
    }

    /// Moments are for the day: deletes yours from before yesterday, so photos don't pile up.
    func deleteOldMoments() async throws {
        let userID = try await userID()
        let yesterday = PalsDay.key(Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
        let mine = try await query(RecordType.moment, NSPredicate(format: "userID == %@", userID))
        // Day keys are yyyy-MM-dd, so string order is date order.
        let old = mine.filter { ($0["day"] as? String ?? "") < yesterday }.map(\.recordID)
        guard !old.isEmpty else { return }
        _ = try await db.modifyRecords(saving: [], deleting: old)
    }

    // MARK: - Push

    /// Keeps this user's CloudKit subscriptions in step with their circles, so a change in any of
    /// them reaches this device as a push right away (the 15 s refresh stays as a fallback):
    ///
    /// - `sub-<code>-Member|Done|Moment|Activity`: silent pushes (content-available) whenever a
    ///   pal joins, finishes, posts or adds something. Uses `circleID`, already queryable.
    /// - `sub-<code>-Prank`: a visible notification when a pal pranks *you* (`toID == me`).
    ///   Needs `Prank.toID` marked Queryable in CloudKit Console (Development, then deploy to
    ///   Production); until then the server rejects just this one and the rest still work.
    ///
    /// Subscriptions belong to the iCloud user (not the device) and live in the public database.
    /// Ones that already exist are left alone; ones for circles you're no longer in are deleted.
    func syncSubscriptions(circles: [(code: String, name: String)]) async throws {
        let me = try await userID()
        let existing = Set(try await db.allSubscriptions().map(\.subscriptionID))

        var wanted: [CKSubscription] = []
        for circle in circles {
            let byCircle = NSPredicate(format: "circleID == %@", circle.code)
            for type in [RecordType.member, RecordType.done, RecordType.moment, RecordType.activity] {
                let subscription = CKQuerySubscription(
                    recordType: type, predicate: byCircle,
                    subscriptionID: Self.subscriptionID(code: circle.code, type: type),
                    options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
                let info = CKSubscription.NotificationInfo()
                info.shouldSendContentAvailable = true // silent: just wakes the app to refresh
                subscription.notificationInfo = info
                wanted.append(subscription)
            }

            let prank = CKQuerySubscription(
                recordType: RecordType.prank,
                predicate: NSPredicate(format: "circleID == %@ AND toID == %@", circle.code, me),
                subscriptionID: Self.subscriptionID(code: circle.code, type: RecordType.prank),
                options: [.firesOnRecordCreation])
            let info = CKSubscription.NotificationInfo()
            // The text is fixed per subscription (who sent it isn't on the record), so it keeps
            // the suspense: the app shows who it was when it opens.
            info.title = "\(circle.name) 👀"
            info.alertBody = "Someone just pranked you. Open Pals to see who."
            info.soundName = "default"
            info.shouldSendContentAvailable = true // also refresh, so the prank is ready to play
            prank.notificationInfo = info
            wanted.append(prank)
        }

        let toSave = wanted.filter { !existing.contains($0.subscriptionID) }
        let wantedIDs = Set(wanted.map(\.subscriptionID))
        let toDelete = existing.filter { $0.hasPrefix("sub-") && !wantedIDs.contains($0) }
        guard !toSave.isEmpty || !toDelete.isEmpty else { return }

        // Saved one by one in a single request; a rejected one (e.g. the Prank subscription
        // before its index is deployed) doesn't stop the others.
        let result = try await db.modifySubscriptions(saving: toSave, deleting: Array(toDelete))
        for (id, outcome) in result.saveResults {
            if case .failure(let error) = outcome {
                PalsError.logOnly(error, context: "subscription \(id)")
            }
        }
    }

    static func subscriptionID(code: String, type: String) -> String { "sub-\(code)-\(type)" }

    // MARK: - Helpers

    private func memberRecord(code: String, userID: String, me: MemberProfile) -> CKRecord {
        let record = CKRecord(recordType: RecordType.member,
                              recordID: CKRecord.ID(recordName: "member-\(code)-\(userID)"))
        record["circleID"] = code
        record["userID"] = userID
        record["name"] = me.name
        record["lastActive"] = Date.now
        if let photo = me.photo { record["avatar"] = Self.asset(photo, maxSide: 400) }
        return record
    }

    /// Whether this user created the record. CloudKit reports your own records' creator as
    /// `CKCurrentUserDefaultName` rather than your user ID.
    private static func isMine(_ record: CKRecord, me: String?) -> Bool {
        guard let creator = record.creatorUserRecordID?.recordName else { return false }
        return creator == CKCurrentUserDefaultName || creator == me
    }

    private func activityRecord(code: String, activity: CircleActivity, addedBy: String, createdAt: Date,
                                id: UUID = UUID()) -> CKRecord {
        let record = CKRecord(recordType: RecordType.activity,
                              recordID: CKRecord.ID(recordName: Self.activityRecordName(code: code, id: id)))
        record["circleID"] = code
        record["emoji"] = activity.emoji
        record["title"] = activity.title
        record["minutes"] = activity.minutes
        record["addedBy"] = addedBy
        record["createdAt"] = createdAt
        return record
    }

    /// Saves records, overwriting whatever is on the server (all our writes are upserts).
    private func save(_ records: [CKRecord]) async throws {
        let result = try await db.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
        for (_, outcome) in result.saveResults {
            if case .failure(let error) = outcome { throw error }
        }
    }

    /// Runs a query and follows its cursor to the end. A record type that doesn't exist yet
    /// (nothing has been saved to it in this environment) reads as empty.
    private func query(_ type: String, _ predicate: NSPredicate) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        do {
            var (results, cursor) = try await db.records(matching: CKQuery(recordType: type, predicate: predicate))
            records += results.compactMap { try? $0.1.get() }
            while let next = cursor {
                (results, cursor) = try await db.records(continuingMatchFrom: next)
                records += results.compactMap { try? $0.1.get() }
            }
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
        return records
    }

    /// 8 characters without look-alikes (no 0/O, 1/I/L): easy to read out, ~40 bits, not guessable.
    static func newCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement()! })
    }

    /// Accepts codes typed with spaces, dashes or lowercase.
    static func normalized(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func asset(_ image: UIImage, maxSide: CGFloat) -> CKAsset? {
        let ratio = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let resized = image.preparingThumbnail(of: size) ?? image
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let url = URL.temporaryDirectory.appending(path: "pals-\(UUID().uuidString).jpg")
        do { try data.write(to: url) } catch { return nil }
        return CKAsset(fileURL: url)
    }

    private static func image(_ value: Any?) -> UIImage? {
        guard let url = (value as? CKAsset)?.fileURL else { return nil }
        return UIImage(contentsOfFile: url.path(percentEncoded: false))
    }
}

// MARK: - Plain data

struct MemberProfile {
    let name: String
    let photo: UIImage?
}

struct CloudCircle {
    let code: String
    let name: String
    let emoji: String
    let colorIndex: Int
    let ownerID: String
    let members: [CloudMember]
    let activities: [CloudActivity]
    /// Who was done on each day: ["2026-11-24": [userID]]
    let done: [String: Set<String>]
    let moments: [CloudMoment]
    let pranks: [CloudPrank]
}

struct CloudMember {
    let userID: String
    let name: String
    let avatar: UIImage?
    let lastActive: Date?
}

struct CloudActivity {
    let recordName: String
    let emoji: String
    let title: String
    let minutes: Int?
    let addedBy: String
    let createdAt: Date?
    /// You added it, so you can edit or delete it.
    let isMine: Bool
}

struct CloudMoment {
    let userID: String
    let back: UIImage
    let front: UIImage
    let postedAt: Date
}

struct CloudPrank {
    let id: String
    let fromID: String
    let toID: String
    let kind: PrankKind
}

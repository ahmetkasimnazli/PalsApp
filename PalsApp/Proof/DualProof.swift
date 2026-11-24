import SwiftUI

/// A BeReal-style proof: what's in front of you (back camera) plus your face (front camera),
/// taken a moment apart. Posting one unlocks your pals' proofs for that circle and day.
struct DualProof: Identifiable, Equatable {
    let id = UUID()
    let back: UIImage
    let front: UIImage
    let author: String
    var authorColor: Color = .palsIndigo
    let time: Date
    var isYours = false

    static func == (a: DualProof, b: DualProof) -> Bool { a.id == b.id }

    /// "now", "12m", "2h"
    var timeLabel: String {
        let minutes = Int(Date.now.timeIntervalSince(time) / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}

/// Keeps your own proofs on disk for the day, one pair of JPEGs per circle.
enum ProofStore {
    private static var folder: URL { URL.applicationSupportDirectory.appending(path: "proofs") }

    private static func base(day: String, circle: String) -> URL {
        let safe = circle.replacingOccurrences(of: "/", with: "-")
        return folder.appending(path: "\(day)_\(safe)")
    }

    static func save(_ proof: DualProof, circle: String) {
        let base = base(day: PalsDay.key(proof.time), circle: circle)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? proof.back.jpegData(compressionQuality: 0.8)?.write(to: base.appendingPathExtension("back.jpg"), options: .atomic)
        try? proof.front.jpegData(compressionQuality: 0.8)?.write(to: base.appendingPathExtension("front.jpg"), options: .atomic)
    }

    static func load(circle: String, author: String) -> DualProof? {
        let base = base(day: PalsDay.key(.now), circle: circle)
        let backURL = base.appendingPathExtension("back.jpg")
        guard let back = UIImage(contentsOfFile: backURL.path(percentEncoded: false)),
              let front = UIImage(contentsOfFile: base.appendingPathExtension("front.jpg").path(percentEncoded: false))
        else { return nil }
        let time = (try? FileManager.default.attributesOfItem(atPath: backURL.path(percentEncoded: false))[.modificationDate] as? Date) ?? .now
        return DualProof(back: back, front: front, author: author, time: time, isYours: true)
    }

    static func delete(circle: String) {
        let base = base(day: PalsDay.key(.now), circle: circle)
        try? FileManager.default.removeItem(at: base.appendingPathExtension("back.jpg"))
        try? FileManager.default.removeItem(at: base.appendingPathExtension("front.jpg"))
    }
}

/// Stand-in moments until they come from a backend (and for the Simulator, which has no camera):
/// stock photos (Unsplash) that match the activity, with a stock selfie for each pal.
enum DemoProofArt {
    static func make(for activity: CircleActivity, author: String, color: Color,
                     photo: UIImage? = nil, minutesAgo: Int = 0, isYours: Bool = false,
                     variant: Int = 1) -> DualProof {
        // Each activity has three photos, so pals doing the same thing don't post the same picture.
        let key = photoKey(for: activity.title)
        let back = UIImage(named: variant == 1 ? "Moment-\(key)" : "Moment-\(key)-\(variant)")
            ?? UIImage(named: "Moment-\(key)") ?? scene(activity)
        let selfieName = isYours ? "You" : author.split(separator: " ").first.map(String.init) ?? author
        let front = photo ?? UIImage(named: "Selfie-\(selfieName)") ?? selfie(author, color: color, photo: nil)
        return DualProof(back: back, front: front, author: author, authorColor: color,
                         time: Date.now.addingTimeInterval(TimeInterval(-minutesAgo * 60)), isYours: isYours)
    }

    /// Which bundled photo fits an activity: exact titles first, then keywords for ones pals added.
    private static func photoKey(for title: String) -> String {
        let exact: [String: String] = [
            "Walk for 5 minutes": "walk", "20 push-ups": "pushups", "Stretch 10 minutes": "stretch",
            "Plank for 1 minute": "plank", "Read 10 pages": "read", "Meditate 5 minutes": "meditate",
            "Write 3 lines in a journal": "journal", "Drink 8 glasses of water": "water",
            "Eat a piece of fruit": "fruit", "In bed before midnight": "bed", "No phone for 1 hour": "nophone",
            "No social media today": "nosocial", "Call someone you miss": "call",
            "Compliment a stranger": "compliment", "10 minutes outside": "outside",
            "Tidy up for 10 minutes": "tidy", "Run 2 km": "run", "No phones at dinner": "dinner",
        ]
        if let key = exact[title] { return key }
        let lower = title.lowercased()
        let keywords: [(String, String)] = [
            ("run", "run"), ("jog", "run"), ("walk", "walk"), ("push", "pushups"), ("plank", "plank"),
            ("stretch", "stretch"), ("yoga", "stretch"), ("read", "read"), ("book", "read"),
            ("meditat", "meditate"), ("breath", "meditate"), ("journal", "journal"), ("write", "journal"),
            ("water", "water"), ("drink", "water"), ("fruit", "fruit"), ("eat", "fruit"), ("sleep", "bed"),
            ("bed", "bed"), ("dinner", "dinner"), ("cook", "dinner"), ("phone", "nophone"),
            ("social", "nosocial"), ("call", "call"), ("friend", "compliment"), ("outside", "outside"),
            ("park", "outside"), ("tidy", "tidy"), ("clean", "tidy"),
        ]
        return keywords.first { lower.contains($0.0) }?.1 ?? ""
    }

    private static func scene(_ activity: CircleActivity) -> UIImage {
        let view = ZStack {
            LinearGradient(colors: [activity.cardColor, activity.cardColor.mix(with: .black, by: 0.35)],
                           startPoint: .top, endPoint: .bottom)
            CardArt(pattern: activity.cardPattern).opacity(0.8)
            Text(activity.emoji)
                .font(.system(size: 150))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
        }
        .frame(width: 300, height: 400)
        return render(view)
    }

    private static func selfie(_ name: String, color: Color, photo: UIImage?) -> UIImage {
        let view = ZStack {
            if let image = photo ?? PalsAvatar.bundledPhoto(for: name) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                color
                Text(name.prefix(1).uppercased())
                    .font(.palsDisplay(90))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 150, height: 200)
        .clipped()
        return render(view)
    }

    private static func render(_ view: some View) -> UIImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage ?? UIImage()
    }
}

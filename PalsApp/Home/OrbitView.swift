import SwiftUI

/// "You" in the middle, up to four friends on a dashed orbit around you.
/// The ring around you fills with the share of the circle that's done today.
struct OrbitView: View {
    let you: String
    let photo: UIImage?
    let streak: Int
    let progress: Double
    let friends: [Friend]
    var onFriendTap: (Friend) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds for one full trip around the orbit.
    private let period: Double = 90
    private let dotAngles: [Double] = [-90, 0, 90, 180]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let rotation = rotation(at: context.date)

            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = CGSize(width: size.width / 2 - 44, height: size.height / 2 - 42)

                ZStack {
                    Ellipse()
                        .stroke(Color.white.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.5, dash: [5, 6], dashPhase: -rotation * 2))
                        .frame(width: radius.width * 2, height: radius.height * 2)
                        .position(center)

                    Ellipse()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: radius.width * 1.35, height: radius.height * 1.35)
                        .position(center)

                    ForEach(dotAngles, id: \.self) { angle in
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .frame(width: 8, height: 8)
                            .position(point(angle + rotation, center: center, radius: radius))
                    }

                    // Friends travel slowly along the orbit, a bit smaller when "further away" (top).
                    let shown = Array(friends.prefix(4))
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, friend in
                        let angle = slotAngle(index, of: shown.count) + rotation
                        friendView(friend)
                            .scaleEffect(depthScale(angle))
                            .position(point(angle, center: center, radius: radius))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { onFriendTap(friend) }
                    }

                    // Drawn last so friends passing behind you stay behind.
                    youView
                        .position(center)
                }
                .contentShape(Rectangle())
                // Friends move every frame, so per-avatar buttons hit-test against stale
                // positions. Instead, find whoever is under the finger right now.
                .gesture(SpatialTapGesture().onEnded { value in
                    if let friend = friend(at: value.location, center: center, radius: radius) {
                        onFriendTap(friend)
                    }
                })
            }
        }
        .animation(Motion.update, value: friends)
        .animation(Motion.update, value: progress)
    }

    private var youView: some View {
        PalsAvatar(name: you, photo: photo, color: .palsIndigo, size: 140)
        .frame(width: 150, height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("You, \(streak) day streak, \(Int(progress * 100)) percent of your circle done today")
    }

    private func friendView(_ friend: Friend) -> some View {
        PalsAvatar(name: friend.name, photo: friend.photo, color: friend.color, size: 76)
            .overlay(alignment: .bottomTrailing) {
                if friend.isActive {
                    Circle()
                        .fill(Color(hex: 0x22C55E))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(Color.palsOffWhite, lineWidth: 3))
                        .offset(x: -2, y: -2)
                }
            }
            .overlay(alignment: .topLeading) {
                // Skipped today → 😴; already pranked → the prank's emoji.
                if let prank = friend.prankedToday {
                    statusBadge(prank.emoji)
                } else if !friend.doneToday {
                    statusBadge("😴")
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(friendLabel(friend))
            .accessibilityHint(friend.doneToday || friend.prankedToday != nil ? "" : "Double tap to prank them")
    }

    private func statusBadge(_ emoji: String) -> some View {
        Text(emoji)
            .font(.system(size: 18))
            .frame(width: 30, height: 30)
            .background(Color.palsOffWhite, in: Circle())
            .offset(x: -4, y: -4)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func friendLabel(_ friend: Friend) -> String {
        var parts = [friend.name]
        if friend.isActive { parts.append("active now") }
        parts.append(friend.doneToday ? "done today" : "hasn't done today's activity")
        if let prank = friend.prankedToday { parts.append("you \(prank.pastTense) them") }
        return parts.joined(separator: ", ")
    }

    private func rotation(at date: Date) -> Double {
        reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: period) / period * 360
    }

    private func slotAngle(_ index: Int, of count: Int) -> Double {
        -135 + Double(index) * 360 / Double(count)
    }

    private func friend(at location: CGPoint, center: CGPoint, radius: CGSize) -> Friend? {
        let shown = Array(friends.prefix(4))
        let rotation = rotation(at: .now)
        let hits = shown.enumerated().map { index, friend in
            let p = point(slotAngle(index, of: shown.count) + rotation, center: center, radius: radius)
            return (friend, hypot(p.x - location.x, p.y - location.y))
        }
        guard let nearest = hits.min(by: { $0.1 < $1.1 }), nearest.1 < 48 else { return nil }
        return nearest.0
    }

    private func depthScale(_ degrees: Double) -> CGFloat {
        0.86 + 0.14 * (sin(degrees * .pi / 180) + 1) / 2
    }

    private func point(_ degrees: Double, center: CGPoint, radius: CGSize) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: center.x + cos(radians) * radius.width,
                       y: center.y + sin(radians) * radius.height)
    }
}

#Preview {
    let model = HomeModel()
    OrbitView(you: "Ahmet", photo: nil, streak: 12, progress: 0.4, friends: model.selectedCircle.friends)
        .frame(height: 320)
        .padding()
        .background(Color.palsOffWhite)
}

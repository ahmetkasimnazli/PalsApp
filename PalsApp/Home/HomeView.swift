import SwiftUI

struct HomeView: View {
    @Bindable var model: HomeModel
    let name: String
    let photo: UIImage?
    var onViewCircle: (PalsCircle.ID) -> Void = { _ in }

    @State private var prankTarget: Friend?
    @State private var viewingProof: DualProof?
    /// Which top-bar stat has its details open.
    @State private var openStat: String?

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
                // Fixed stats row across the top, Duolingo-style: it stays put while the page scrolls.
                .safeAreaInset(edge: .top, spacing: 0) { statsBar }
        }
    }

    /// 🔥 streak and ❄️ freezes side by side on the left, a glass 🔔 on the right.
    private var statsBar: some View {
        HStack(spacing: 18) {
            stat("🔥", value: model.streakDays,
                 // Grey until today's activity is done; Duolingo orange once it is.
                 color: model.completedToday ? Color(hex: 0xFF9600) : .white.opacity(0.55),
                 lit: model.completedToday,
                 label: "\(model.streakDays) day streak")

            stat("❄️", value: model.freezes, color: Color(hex: 0x7DD3FC), lit: true,
                 label: "\(model.freezes) streak freezes")

            Spacer(minLength: 0)

            Button {
                // Demo: stands in for a push from a pal until there's a backend.
                model.receiveDemoPrank()
            } label: {
                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.palsPink, .white)
                    .font(.system(size: 19))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Notifications")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(Color.palsIndigo)
    }

    private func stat(_ emoji: String, value: Int, color: Color, lit: Bool, label: String) -> some View {
        Button { openStat = emoji } label: {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 24))
                    .saturation(lit ? 1 : 0)
                Text("\(value)")
                    .font(.pals(21, weight: .bold))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
        .accessibilityHint("Shows your streak")
        .popover(isPresented: Binding(get: { openStat == emoji }, set: { if !$0 { openStat = nil } }),
                 arrowEdge: .top) {
            StreakPopover(streak: model.streakDays, freezes: model.freezes, doneToday: model.completedToday)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleRow
                    .padding(.top, 4)

                OrbitView(
                    you: name.isEmpty ? "You" : name,
                    photo: photo,
                    streak: model.streakDays,
                    progress: model.circleProgress,
                    friends: model.selectedCircle.friends,
                    onFriendTap: tapped
                )
                .frame(height: 300)
                .padding(.horizontal, -8)

                DailyCardView(model: model)
                    .padding(.top, 6)

                ProofStrip(model: model, circle: model.selectedCircle, onDark: true) {
                    model.startActivity()
                }
                .padding(.top, 18)
                .padding(.bottom, 14)

                TodayCard(
                    circle: model.selectedCircle,
                    youDone: model.completedToday,
                    onPrank: { prankTarget = $0 },
                    onViewAll: { onViewCircle(model.selectedCircleID) }
                )
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.palsIndigo.ignoresSafeArea())
        .fullScreenCover(item: $viewingProof) { proof in
            ProofViewer(proofs: model.proofs(in: model.selectedCircle), startAt: proof.id)
        }
        .sheet(item: $prankTarget) { friend in
            PrankSheet(
                friend: model.friend(id: friend.id) ?? friend,
                onSend: { kind in
                    withAnimation(Motion.update) { model.sendPrank(kind, to: friend.id) }
                    Task {
                        // Let the sheet slide away, then play it on your screen too.
                        try? await Task.sleep(for: .milliseconds(450))
                        model.playSentPrank(kind, to: friend)
                    }
                },
                onPreview: { kind in
                    prankTarget = nil
                    Task {
                        // Let the sheet slide away before the prank plays.
                        try? await Task.sleep(for: .milliseconds(450))
                        model.previewPrank(kind, for: friend)
                    }
                }
            )
            .preferredColorScheme(.light)
        }
    }

    /// A pal who posted a proof opens it (once yours is posted); anyone else opens the prank sheet.
    private func tapped(_ friend: Friend) {
        let circle = model.selectedCircle
        if model.myProof(in: circle) != nil,
           let proof = model.proofs(in: circle).first(where: { !$0.isYours && $0.author == friend.name }) {
            viewingProof = proof
        } else {
            prankTarget = friend
        }
    }

    // MARK: - Sections

    /// The circle's name as the page title (no logo in the UI, per the HIG),
    /// with a glass button beside it to switch circles.
    private var titleRow: some View {
        HStack(spacing: 4) {
            Text(model.selectedCircle.name)
                .font(.pals(34, weight: .black, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)

            Menu {
                Picker("Circle", selection: $model.selectedCircleID.animation(Motion.select)) {
                    ForEach(model.circles) { circle in
                        Text("\(circle.emoji) \(circle.name)").tag(circle.id)
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.interactive(), in: .circle)
                    // Looks small, but stays a full 44 pt to tap.
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .accessibilityLabel("Switch circle")

            Spacer(minLength: 0)
        }
    }

}

#Preview {
    HomeView(model: HomeModel(), name: "Ahmet", photo: nil)
}

/// What the 🔥 in the top bar opens.
private struct StreakPopover: View {
    let streak: Int
    let freezes: Int
    let doneToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("🔥")
                    .font(.system(size: 34))
                    .saturation(doneToday ? 1 : 0)
                Text(streak == 1 ? "1 day" : "\(streak) days")
                    .font(.palsDisplay(36))
                    .tracking(-1)
            }
            Text(doneToday ? "Done today. Your streak is safe 🙌"
                           : "Do today's activity to keep it going.")
                .font(.palsBody(15))
                .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 10) {
                Text("❄️")
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 1) {
                    Text(freezes == 1 ? "1 freeze" : "\(freezes) freezes")
                        .font(.pals(16))
                    Text("Saves your streak on a day you miss.")
                        .font(.palsBody(13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

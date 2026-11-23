import SwiftUI

struct HomeView: View {
    @Bindable var model: HomeModel
    let name: String
    let photo: UIImage?
    var onViewCircle: (PalsCircle.ID) -> Void = { _ in }

    @State private var prankTarget: Friend?

    var body: some View {
        NavigationStack {
            content
                // The title row lives in the page so the switch button can sit right next to it.
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            // Demo: stands in for a push from a pal until there's a backend.
                            model.receiveDemoPrank()
                        } label: {
                            Image(systemName: "bell.badge")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color.palsPink, .white)
                        }
                        .accessibilityLabel("Notifications")
                    }
                }
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
                    onFriendTap: { prankTarget = $0 }
                )
                .frame(height: 300)
                .padding(.horizontal, -8)

                TodayCard(
                    circle: model.selectedCircle,
                    youDone: model.completedToday,
                    onPrank: { prankTarget = $0 },
                    onViewAll: { onViewCircle(model.selectedCircleID) }
                )
                .padding(.top, 4)

                streakCard
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.palsIndigo.ignoresSafeArea())
        .sheet(item: $prankTarget) { friend in
            PrankSheet(
                friend: model.friend(id: friend.id) ?? friend,
                onSend: { kind in
                    withAnimation(.spring) { model.sendPrank(kind, to: friend.id) }
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
                Picker("Circle", selection: $model.selectedCircleID.animation(.snappy)) {
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

    private var streakCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR STREAK")
                    .font(.pals(14))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.streakDays == 1 ? "1 day" : "\(model.streakDays) days")
                        .font(.palsDisplay(40))
                        .tracking(-1)
                        .contentTransition(.numericText())
                    Text("🔥")
                        .font(.system(size: 30))
                }
                .foregroundStyle(Color.palsOffWhite)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "snowflake")
                Text("\(model.freezes) freezes")
            }
            .font(.pals(15))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.18), in: Capsule())
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }

}

#Preview {
    HomeView(model: HomeModel(), name: "Ahmet", photo: nil)
}

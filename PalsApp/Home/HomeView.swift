import SwiftUI

struct HomeView: View {
    @Bindable var model: HomeModel
    let name: String
    let photo: UIImage?
    var onViewCircle: (PalsCircle.ID) -> Void = { _ in }

    @State private var prankTarget: Friend?
    /// How far past the top the user is pulling (points, 0 when not overscrolling).
    @State private var pull: CGFloat = 0

    /// Logo grows with the pull (rubber-band style) and settles back on release.
    private var logoScale: CGFloat { 1 + min(pull, 220) / 140 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 8)

                titleRow
                    .padding(.top, 12)

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
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, newPull in
            pull = newPull
        }
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

    private var header: some View {
        HStack(spacing: 14) {
            Image("SplashLogo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.palsOffWhite)
                .frame(height: 56)
                // Anchor near the visible lettering (the bitmap has padding around it).
                .scaleEffect(logoScale, anchor: UnitPoint(x: 0.12, y: 0.55))
                .padding(.leading, -16)
                .zIndex(1)
                .accessibilityLabel("Pals")

            Spacer()

            Button {
                // Demo: stands in for a push from a pal until there's a backend.
                model.receiveDemoPrank()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.palsPink)
                    .frame(width: 10, height: 10)
                    .offset(x: -6, y: 6)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel("Notifications")

            PalsAvatar(name: name.isEmpty ? "You" : name, photo: photo, size: 44)
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center) {
            Menu {
                Picker("Circle", selection: $model.selectedCircleID) {
                    ForEach(model.circles) { circle in
                        Text(circle.name).tag(circle.id)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                    Text(model.selectedCircle.name)
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.pals(14))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer()
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

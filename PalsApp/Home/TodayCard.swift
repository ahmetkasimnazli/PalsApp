import SwiftUI

/// Home screen summary of today in the selected circle: how many are done,
/// who's active, and a one-tap prank for everyone who skipped.
struct TodayCard: View {
    let circle: PalsCircle
    let youDone: Bool
    var onPrank: (Friend) -> Void
    var onViewAll: () -> Void

    private var doneCount: Int { circle.friends.filter(\.doneToday).count + (youDone ? 1 : 0) }
    private var total: Int { circle.friends.count + 1 }
    private var activeCount: Int { circle.friends.filter(\.isActive).count }
    private var skipped: [Friend] { circle.friends.filter { !$0.doneToday } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            segments
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
            if skipped.isEmpty {
                Text("Everyone's done today 🎉")
                    .font(.pals(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(skipped) { friend in
                        skippedRow(friend)
                    }
                }
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.spring(duration: 0.4), value: circle)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(doneCount)/\(total)")
                    .font(.palsDisplay(40))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("done today")
                    .font(.palsBody(14))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: 0x22C55E))
                        .frame(width: 8, height: 8)
                    Text("\(activeCount) active")
                        .font(.pals(13))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: Capsule())

                Button(action: onViewAll) {
                    HStack(spacing: 2) {
                        Text("View all")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.pals(14))
                    .foregroundStyle(.white)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View all of \(circle.name)")
            }
        }
    }

    /// One segment per person; filled when they're done.
    private var segments: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < doneCount ? Color.white : Color.white.opacity(0.2))
                    .frame(height: 10)
            }
        }
        .accessibilityHidden(true)
    }

    private func skippedRow(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            PalsAvatar(name: friend.name, color: friend.color, size: 42)
                .overlay(alignment: .topLeading) {
                    Text("😴")
                        .font(.system(size: 13))
                        .frame(width: 22, height: 22)
                        .background(.white, in: Circle())
                        .offset(x: -5, y: -5)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(.pals(17))
                    .foregroundStyle(.white)
                Text("Hasn't done it yet")
                    .font(.palsBody(13))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            if let prank = friend.prankedToday {
                Text("\(prank.pastTense.capitalized) \(prank.emoji)")
                    .font(.pals(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.15), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button { onPrank(friend) } label: {
                    Text("Prank 😈")
                        .font(.pals(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.palsPink).interactive(), in: .capsule)
                .accessibilityLabel("Prank \(friend.name)")
            }
        }
    }
}

#Preview {
    let model = HomeModel()
    TodayCard(circle: model.selectedCircle, youDone: false, onPrank: { _ in }, onViewAll: {})
        .padding()
        .background(Color.palsOffWhite)
}

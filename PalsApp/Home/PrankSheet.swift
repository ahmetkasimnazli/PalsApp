import SwiftUI

/// Opened by tapping a pal on the orbit. If they skipped today, pick a prank to send.
struct PrankSheet: View {
    let friend: Friend
    var onSend: (PrankKind) -> Void
    var onPreview: (PrankKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: PrankKind = .slap

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PalsAvatar(name: friend.name, photo: friend.photo, color: friend.color, size: 56)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.palsInk)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressableStyle())
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Close")
                }

                if friend.doneToday {
                    HighlightHeadline(lines: [friend.name], highlight: "did it today", size: 44)
                    Text("No prank needed. Respect. 💪")
                        .font(.palsBody(17))
                        .foregroundStyle(Color.palsInk.opacity(0.7))
                } else if let sent = friend.prankedToday {
                    HighlightHeadline(lines: [friend.name], highlight: "got \(sent.pastTense) \(sent.emoji)", size: 44)
                    Text("One prank a day. They'll get it the next time they open Pals.")
                        .font(.palsBody(17))
                        .foregroundStyle(Color.palsInk.opacity(0.7))
                } else {
                    HighlightHeadline(lines: ["\(friend.name) skipped"], highlight: "Prank them", size: 42,
                        info: "Pick a card. It plays on their screen the next time they open Pals.")

                    // Edge to edge, so the side cards peek in from the sheet's edges.
                    PrankPicker(selected: $selected)
                        .padding(.horizontal, -24)
                        .padding(.top, 4)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if canPrank { sendBar }
        }
        .presentationDetents([.large])
        .presentationBackground(Color.palsOffWhite)
    }

    private var canPrank: Bool { !friend.doneToday && friend.prankedToday == nil }

    /// Send (and try it on yourself), always in reach at the bottom.
    private var sendBar: some View {
        VStack(spacing: 6) {
            Button {
                onSend(selected)
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text("Send the \(selected.title.lowercased())")
                    Text(selected.emoji)
                }
                .font(.pals(22, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Capsule())
                .contentTransition(.opacity)
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.tint(selected.cardColor).interactive(), in: .capsule)

            Button {
                onPreview(selected)
            } label: {
                Text("Try it on me first")
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .background(Color.palsOffWhite)
    }
}

#Preview {
    Text("Home")
        .sheet(isPresented: .constant(true)) {
            PrankSheet(
                friend: Friend(name: "Pasquale", color: .palsIndigo, isActive: true, doneToday: false),
                onSend: { _ in },
                onPreview: { _ in }
            )
        }
}

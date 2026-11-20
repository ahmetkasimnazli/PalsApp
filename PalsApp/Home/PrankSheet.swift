import SwiftUI

/// Opened by tapping a pal on the orbit. If they skipped today, pick a prank to send.
struct PrankSheet: View {
    let friend: Friend
    var onSend: (PrankKind) -> Void
    var onPreview: (PrankKind) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: PrankKind = .slap

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                PalsAvatar(name: friend.name, color: friend.color, size: 56)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.palsInk)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            }

            if friend.doneToday {
                HighlightHeadline(lines: [friend.name], highlight: "did it today.", size: 44)
                Text("No prank needed. Respect. 💪")
                    .font(.palsBody(17))
                    .foregroundStyle(Color.palsInk.opacity(0.7))
            } else if let sent = friend.prankedToday {
                HighlightHeadline(lines: [friend.name], highlight: "got \(sent.pastTense). \(sent.emoji)", size: 44)
                Text("One prank a day. They'll get it the next time they open Pals.")
                    .font(.palsBody(17))
                    .foregroundStyle(Color.palsInk.opacity(0.7))
            } else {
                pickPrank
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .presentationDetents([.large])
        .presentationBackground(Color.palsOffWhite)
    }

    private var pickPrank: some View {
        VStack(alignment: .leading, spacing: 18) {
            HighlightHeadline(lines: ["\(friend.name) skipped."], highlight: "Prank them.", size: 42)

            Text("They haven't done today's walk yet. Pick a punishment — it plays on their screen the next time they open Pals.")
                .font(.palsBody(16))
                .foregroundStyle(Color.palsInk.opacity(0.7))

            HStack(spacing: 12) {
                ForEach(PrankKind.allCases) { kind in
                    option(kind)
                }
            }
            .padding(.top, 4)

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
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
            .padding(.top, 8)

            Button {
                onPreview(selected)
            } label: {
                Text("Try it on me first")
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
    }

    private func option(_ kind: PrankKind) -> some View {
        let isSelected = kind == selected
        return Button {
            withAnimation(.spring(duration: 0.3)) { selected = kind }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.emoji)
                    .font(.system(size: 52))
                    .rotationEffect(.degrees(isSelected ? -10 : 0))
                Text(kind.title)
                    .font(.palsDisplay(24))
                    .foregroundStyle(Color.palsInk)
                Text(kind.pitch)
                    .font(.palsBody(13))
                    .foregroundStyle(Color.palsInk.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? Color.palsBlue.opacity(0.1) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? Color.palsBlue : Color.palsInk.opacity(0.1), lineWidth: isSelected ? 2.5 : 1)
            )
            .scaleEffect(isSelected ? 1 : 0.97)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

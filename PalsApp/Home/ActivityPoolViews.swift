import SwiftUI

// MARK: - Add activity

/// Lets anyone in a circle add an activity to its pool, or change one they added.
struct AddActivitySheet: View {
    /// The activity being changed; `nil` adds a new one.
    var editing: CircleActivity? = nil
    var onAdd: (CircleActivity) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var emoji: String
    @State private var minutes: Int?
    @State private var category: ActivityCategory?

    init(editing: CircleActivity? = nil, onAdd: @escaping (CircleActivity) -> Void) {
        self.editing = editing
        self.onAdd = onAdd
        _title = State(initialValue: editing?.title ?? "")
        _emoji = State(initialValue: editing?.emoji ?? "✨")
        _minutes = State(initialValue: editing?.minutes)
    }

    private var isEditing: Bool { editing != nil }
    /// Nothing to save while the edit matches what's there.
    private var unchanged: Bool {
        guard let editing else { return false }
        return editing.title == trimmed && editing.emoji == emoji && editing.minutes == minutes
    }
    private var canSave: Bool { !trimmed.isEmpty && !unchanged }


    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    HighlightHeadline(lines: [isEditing ? "Edit" : "New"], highlight: "activity", size: 44)
                    Spacer()
                    CloseButton { dismiss() }
                }

                section("Ideas") {
                    VStack(alignment: .leading, spacing: 12) {
                        CategoryBlob(selected: $category)
                        if let category {
                            FlowLayout(spacing: 8) {
                                ForEach(category.ideas, id: \.title) { idea in
                                    let isOn = idea.title == title
                                    Button {
                                        title = idea.title
                                        emoji = idea.emoji
                                        minutes = idea.minutes
                                    } label: {
                                        Text("\(idea.emoji) \(idea.title)")
                                            .font(.pals(14))
                                            .foregroundStyle(isOn ? .white : Color.palsInk)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isOn ? category.color : .white, in: Capsule())
                                    }
                                    .buttonStyle(PressableStyle())
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            Text("Tap a bubble for ideas, or write your own below.")
                                .font(.palsBody(13))
                                .foregroundStyle(Color.palsInk.opacity(0.5))
                        }
                    }
                }

                section("What's the activity?") {
                    TextField("e.g. 15 squats", text: $title)
                        .font(.palsBody(17))
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(.white, in: Capsule())
                }

                section("Emoji") {
                    EmojiField(emoji: $emoji)
                }

                section("Timer") {
                    TimerDial(minutes: $minutes)
                }

                Text(isEditing
                     ? "The change shows up for everyone in the circle."
                     : "It joins the circle's pool. Each day one activity from the pool is picked for everyone.")
                    .font(.palsBody(14))
                    .foregroundStyle(Color.palsInk.opacity(0.5))

                Button {
                    onAdd(CircleActivity(emoji: emoji, title: trimmed, minutes: minutes))
                    dismiss()
                } label: {
                    Text(isEditing ? "Save changes" : "Add activity")
                        .font(.pals(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.palsBlue.opacity(canSave ? 1 : 0.4)).interactive(canSave), in: .capsule)
                .disabled(!canSave)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .presentationBackground(Color.palsOffWhite)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.pals(13))
                .tracking(1)
                .foregroundStyle(Color.palsInk.opacity(0.5))
            content()
        }
    }
}

// MARK: - Shared pieces

/// A white row for one activity: emoji, title, timer, and optionally who already did it today.
struct ActivityRow<Trailing: View>: View {
    let activity: CircleActivity
    let people: [Friend]
    /// Small extra text after the timer, e.g. "by Pasquale".
    var note: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(activity.emoji)
                .font(.system(size: 26))
                .frame(width: 52, height: 52)
                .background(Color.palsOffWhite, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(activity.title)
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(activity.durationLabel, systemImage: activity.minutes == nil ? "checkmark.circle" : "timer")
                        .font(.palsBody(13))
                        .foregroundStyle(Color.palsInk.opacity(0.55))
                        .lineLimit(1)
                    if let note {
                        Text(note)
                            .font(.palsBody(13))
                            .foregroundStyle(Color.palsInk.opacity(0.4))
                            .lineLimit(1)
                    }
                    MiniAvatars(people: people)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Small overlapping avatars of who did something ("You" shows your own photo).
struct MiniAvatars: View {
    let people: [Friend]
    var size: CGFloat = 24
    /// Off inside transformed views (e.g. a flipping card), where Liquid Glass misrenders.
    var glass = true

    var body: some View {
        if !people.isEmpty {
            HStack(spacing: -size * 0.35) {
                ForEach(people.prefix(4)) { person in
                    if person.name == "You" {
                        PalsAvatar(name: UserDefaults.standard.string(forKey: "profileName") ?? "You",
                                   photo: ProfilePhotoStore.load(), size: size, glass: glass)
                    } else {
                        PalsAvatar(name: person.name, photo: person.photo, color: person.color, size: size, glass: glass)
                    }
                }
                if people.count > 4 {
                    Text("+\(people.count - 4)")
                        .font(.pals(size * 0.42))
                        .foregroundStyle(Color.palsInk)
                        .frame(width: size, height: size)
                        .background(Color.palsOffWhite, in: Circle())
                }
            }
            .accessibilityLabel("Done by " + people.map(\.name).joined(separator: ", "))
        }
    }
}

struct DonePill: View {
    var body: some View {
        Text("Done ✓")
            .font(.pals(13))
            .foregroundStyle(Color(hex: 0x15803D))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(hex: 0x22C55E).opacity(0.15), in: Capsule())
    }
}

struct CloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.palsInk)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(PressableStyle())
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Close")
    }
}

import SwiftUI

/// Circles tab: every group you're in, its daily activity and how it's going today.
struct CirclesView: View {
    @Bindable var model: HomeModel
    @Binding var path: [PalsCircle.ID]
    var onOpenOrbit: () -> Void

    @State private var showingNewCircle = false
    @State private var showingJoin = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HighlightHeadline(lines: ["Your"], highlight: "circles", size: 52)
                        .padding(.top, 12)

                    Text("Every day each circle gets one activity from its pool. Skip it, and your pals get to prank you.")
                        .font(.palsBody(16))
                        .foregroundStyle(Color.palsInk.opacity(0.65))
                        .padding(.top, 10)

                    if model.isDemo {
                        Label(model.cloudStatus == .signedOut
                              ? "These are demo circles. Sign in to iCloud to make real ones."
                              : "These are demo circles. Create one or join with a code to start for real.",
                              systemImage: "sparkles")
                            .font(.palsBody(14))
                            .foregroundStyle(Color.palsBlue)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.palsBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .padding(.top, 14)
                    }

                    VStack(spacing: 14) {
                        ForEach(model.circles) { circle in
                            NavigationLink(value: circle.id) {
                                CircleCard(circle: circle,
                                           revealed: model.isRevealed(circle),
                                           progress: model.progress(of: circle),
                                           done: model.doneCount(in: circle),
                                           isHome: circle.id == model.selectedCircleID)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.top, 22)

                    Button {
                        showingNewCircle = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .fontWeight(.heavy)
                            Text("New circle")
                        }
                        .font(.pals(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
                    .padding(.top, 22)

                    Button {
                        showingJoin = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                            Text("Join with a code")
                        }
                        .font(.pals(18))
                        .foregroundStyle(Color.palsInk)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.palsOffWhite.ignoresSafeArea())
            .navigationDestination(for: PalsCircle.ID.self) { id in
                CircleDetailView(model: model, circleID: id, onOpenOrbit: onOpenOrbit)
            }
            .navigationTitle("Circles")
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingNewCircle) {
            NewCircleSheet(model: model)
        }
        .sheet(isPresented: $showingJoin) {
            JoinCircleSheet(model: model)
                .presentationDetents([.medium])
        }
    }
}

// MARK: - Card

private struct CircleCard: View {
    let circle: PalsCircle
    let revealed: Bool
    let progress: Double
    let done: Int
    let isHome: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(circle.emoji)
                    .font(.system(size: 30))
                    .frame(width: 54, height: 54)
                    .background(circle.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    if isHome {
                        Text("ON ORBIT")
                            .font(.pals(10))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.palsBlue, in: Capsule())
                    }
                    Text(circle.name)
                        .font(.pals(22, weight: .bold))
                        .foregroundStyle(Color.palsInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(revealed ? "Today: \(circle.today.emoji) \(circle.today.title)" : "Today: 🃏 card not drawn yet")
                        .font(.palsBody(15))
                        .foregroundStyle(Color.palsInk.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("🔥 \(circle.streak)")
                    .font(.pals(16))
                    .foregroundStyle(Color.palsInk)
            }

            HStack {
                AvatarStack(friends: circle.friends)
                Spacer()
                Text("\(done)/\(circle.friends.count + 1) done")
                    .font(.pals(14))
                    .foregroundStyle(Color.palsInk.opacity(0.7))
            }

            ProgressBar(value: progress, color: circle.color)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(isHome ? Color.palsInk : Color.palsInk.opacity(0.08), lineWidth: isHome ? 2 : 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct AvatarStack: View {
    let friends: [Friend]

    var body: some View {
        HStack(spacing: -12) {
            ForEach(friends.prefix(5)) { friend in
                PalsAvatar(name: friend.name, photo: friend.photo, color: friend.color, size: 36)
            }
            if friends.count > 5 {
                Text("+\(friends.count - 5)")
                    .font(.pals(12))
                    .foregroundStyle(Color.palsInk)
                    .frame(width: 36, height: 36)
                    .background(Color.palsOffWhite, in: Circle())
            }
        }
    }
}

private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.palsInk.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: max(10, proxy.size.width * value))
            }
        }
        .frame(height: 10)
        .animation(Motion.update, value: value)
    }
}

// MARK: - Detail

private struct CircleDetailView: View {
    @Bindable var model: HomeModel
    let circleID: PalsCircle.ID
    var onOpenOrbit: () -> Void

    @State private var prankTarget: Friend?
    @State private var addingActivity = false

    private var circle: PalsCircle? { model.circles.first { $0.id == circleID } }

    var body: some View {
        if let circle {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(circle.emoji).font(.system(size: 44))
                        HighlightHeadline(lines: [], highlight: circle.name, size: 40)
                    }

                    activityCard(circle)
                        .padding(.top, 18)

                    ProofStrip(model: model, circle: circle) {
                        model.selectedCircleID = circle.id
                        // The card draw happens on the Orbit.
                        if !model.isRevealed(circle) { onOpenOrbit() }
                        model.startActivity()
                    }
                    .padding(.top, 26)

                    activitiesSection(circle)

                    Text("PALS")
                        .font(.pals(14))
                        .tracking(1)
                        .foregroundStyle(Color.palsInk.opacity(0.5))
                        .padding(.top, 26)

                    VStack(spacing: 0) {
                        youRow
                        ForEach(circle.friends) { friend in
                            Divider().padding(.leading, 70)
                            memberRow(friend)
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.top, 10)

                    if let code = circle.code {
                        InviteCard(circleName: circle.name, code: code)
                            .padding(.top, 22)
                    }

                    if circle.id != model.selectedCircleID {
                        Button {
                            withAnimation { model.selectedCircleID = circle.id }
                            onOpenOrbit()
                        } label: {
                            Text("Show on my orbit")
                                .font(.pals(18))
                                .foregroundStyle(Color.palsInk)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.palsOffWhite.ignoresSafeArea())
            // The system bar gives a standard back button and the edge swipe to go back.
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $addingActivity) {
                AddActivitySheet { activity in
                    withAnimation { model.addActivity(activity, to: circleID) }
                }
            }
            .sheet(item: $prankTarget) { friend in
                PrankSheet(
                    friend: model.friend(id: friend.id) ?? friend,
                    onSend: { kind in
                        withAnimation(Motion.update) { model.sendPrank(kind, to: friend.id, in: circleID) }
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            model.playSentPrank(kind, to: friend)
                        }
                    },
                    onPreview: { kind in
                        prankTarget = nil
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            model.previewPrank(kind, for: friend)
                        }
                    }
                )
            }
        }
    }

    private func activityCard(_ circle: PalsCircle) -> some View {
        let revealed = model.isRevealed(circle)
        let today = circle.today
        return VStack(alignment: .leading, spacing: 10) {
            Text("TODAY EVERYONE DOES")
                .font(.pals(13))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .center, spacing: 12) {
                Text(revealed ? today.emoji : "🃏")
                    .font(.system(size: 34))
                Text(revealed ? today.title : "Card not drawn yet")
                    .font(.pals(28, weight: .bold))
                    .foregroundStyle(Color.palsOffWhite)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            HStack {
                Text(circle.streak == 1 ? "🔥 1 day together" : "🔥 \(circle.streak) days together")
                Spacer()
                Text("\(model.doneCount(in: circle))/\(circle.friends.count + 1) done")
            }
            .font(.pals(15))
            .foregroundStyle(.white.opacity(0.9))
            ProgressBar(value: model.progress(of: circle), color: .white)

            if !revealed {
                Text("Draw it from the deck on your Orbit.")
                    .font(.palsBody(14))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(Color.palsIndigo, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func activitiesSection(_ circle: PalsCircle) -> some View {
        // Only mark today's activity once its card has been drawn.
        let todayID = model.isRevealed(circle) ? circle.today.id : nil
        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle("THE POOL")
                .padding(.top, 26)
            Text("Every day one card is drawn from this deck for everyone. Tap to fan it out; anyone can add a card.")
                .font(.palsBody(14))
                .foregroundStyle(Color.palsInk.opacity(0.5))

            PoolDeck(pool: circle.pool, todayID: todayID)
                .padding(.top, 6)

            Button { addingActivity = true } label: {
                Label("Add an activity", systemImage: "plus")
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.top, 4)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.pals(14))
            .tracking(1)
            .foregroundStyle(Color.palsInk.opacity(0.5))
    }

    private var youRow: some View {
        HStack(spacing: 14) {
            PalsAvatar(name: UserDefaults.standard.string(forKey: "profileName") ?? "You",
                       photo: ProfilePhotoStore.load(), size: 46)
            Text("You")
                .font(.pals(18))
                .foregroundStyle(Color.palsInk)
            Spacer()
            if let circle, let proof = model.myProof(in: circle) {
                Image(uiImage: proof.back)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .rotationEffect(.degrees(-6))
                    .accessibilityLabel("Your moment")
            }
            if let circle {
                statusPill(model.isDone(in: circle) ? "Done ✓" : "Not yet", done: model.isDone(in: circle))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func memberRow(_ friend: Friend) -> some View {
        HStack(spacing: 14) {
            PalsAvatar(name: friend.name, photo: friend.photo, color: friend.color, size: 46)
                .overlay(alignment: .bottomTrailing) {
                    if friend.isActive {
                        Circle()
                            .fill(Color(hex: 0x22C55E))
                            .frame(width: 13, height: 13)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(.pals(18))
                    .foregroundStyle(Color.palsInk)
                Text(friend.isActive ? "Active now" : "Away")
                    .font(.palsBody(13))
                    .foregroundStyle(Color.palsInk.opacity(0.5))
            }
            Spacer()
            if friend.doneToday {
                statusPill("Done ✓", done: true)
            } else if let prank = friend.prankedToday {
                statusPill("\(prank.pastTense.capitalized) \(prank.emoji)", done: false)
            } else {
                Button {
                    prankTarget = friend
                } label: {
                    Text("Prank 😈")
                        .font(.pals(14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.palsPink).interactive(), in: .capsule)
                .accessibilityLabel("Prank \(friend.name)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func statusPill(_ text: String, done: Bool) -> some View {
        Text(text)
            .font(.pals(13))
            .foregroundStyle(done ? Color(hex: 0x15803D) : Color.palsInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(done ? Color(hex: 0x22C55E).opacity(0.15) : Color.palsInk.opacity(0.08), in: Capsule())
    }
}

// MARK: - New circle

private struct NewCircleSheet: View {
    @Bindable var model: HomeModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🎯"
    @State private var picked: Set<String> = ["Walk for 5 minutes"]
    @State private var members = Set<Friend.ID>()
    @State private var creating = false
    /// Set once a real circle exists, to show its invite code.
    @State private var createdCode: String?

    private let emojis = ["🎯", "📚", "🧘", "🏃", "🎸", "🥗", "💧", "☀️"]
    private var activities: [String] { CircleActivity.suggestions.map(\.title) }

    private var canCreate: Bool {
        // Real circles start with just you; pals join with the invite code.
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !picked.isEmpty
            && (model.canUseCloud || !members.isEmpty) && !creating
    }

    var body: some View {
        if let createdCode {
            createdView(code: createdCode)
        } else {
            form
        }
    }

    /// After a real circle is made: its invite code, ready to share.
    private func createdView(code: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HighlightHeadline(lines: ["Circle"], highlight: "created", size: 44)
            Text("Share the code with your pals. They open Pals, tap Join with a code and type it in.")
                .font(.palsBody(16))
                .foregroundStyle(Color.palsInk.opacity(0.65))
            InviteCard(circleName: name, code: code)
            Spacer()
            Button { dismiss() } label: {
                Text("Done")
                    .font(.pals(20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.palsOffWhite.ignoresSafeArea())
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    HighlightHeadline(lines: ["New"], highlight: "circle", size: 44)
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

                section("Name") {
                    TextField("e.g. Book Club", text: $name)
                        .font(.palsBody(17))
                        .padding(.horizontal, 20)
                        .frame(height: 48)
                        .background(.white, in: Capsule())
                }

                section("Icon") {
                    HStack(spacing: 8) {
                        ForEach(emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e)
                                    .font(.system(size: 24))
                                    .frame(width: 38, height: 38)
                                    .background(.white, in: Circle())
                                    .overlay(Circle().strokeBorder(Color.palsBlue, lineWidth: e == emoji ? 2.5 : 0))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityAddTraits(e == emoji ? .isSelected : [])
                        }
                    }
                }

                section("What will you do together?") {
                    VStack(alignment: .leading, spacing: 10) {
                        PassionPicker(picked: $picked)
                        Text("Pick a few. Each day one of them is chosen for everyone, and anyone can add more later.")
                            .font(.palsBody(13))
                            .foregroundStyle(Color.palsInk.opacity(0.5))
                    }
                }

                if model.canUseCloud {
                    Label("You'll get an invite code to share with your pals.", systemImage: "person.2.badge.plus")
                        .font(.palsBody(15))
                        .foregroundStyle(Color.palsInk.opacity(0.6))
                } else {
                section("Pals") {
                    VStack(spacing: 0) {
                        ForEach(model.allPals) { pal in
                            Button {
                                if members.contains(pal.id) { members.remove(pal.id) } else { members.insert(pal.id) }
                            } label: {
                                HStack(spacing: 12) {
                                    PalsAvatar(name: pal.name, photo: pal.photo, color: pal.color, size: 38)
                                    Text(pal.name)
                                        .font(.pals(17))
                                        .foregroundStyle(Color.palsInk)
                                    Spacer()
                                    Image(systemName: members.contains(pal.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(members.contains(pal.id) ? Color.palsBlue : Color.palsInk.opacity(0.25))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityAddTraits(members.contains(pal.id) ? .isSelected : [])
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                }

                Button {
                    creating = true
                    Task {
                        let code = await model.createCircle(name: name.trimmingCharacters(in: .whitespaces),
                                                            emoji: emoji,
                                                            activities: activities.filter(picked.contains),
                                                            memberIDs: members)
                        creating = false
                        if let code { withAnimation(Motion.appear) { createdCode = code } }
                        else if model.cloudError == nil { dismiss() }
                    }
                } label: {
                    Text(creating ? "Creating…" : "Create circle")
                        .font(.pals(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.palsBlue.opacity(canCreate ? 1 : 0.4)).interactive(canCreate), in: .capsule)
                .disabled(!canCreate)
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
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

/// Wrapping row of selectable chips.
private struct FlowChips: View {
    let items: [String]
    let selected: Set<String>
    var onSelect: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isOn = selected.contains(item)
                Button { onSelect(item) } label: {
                    Text("\(CircleActivity.suggestion(item).emoji) \(item)")
                        .font(.pals(14))
                        .foregroundStyle(isOn ? .white : Color.palsInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(isOn ? Color.palsBlue : .white, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        rows(for: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, point) in rows(for: bounds.width, subviews: subviews).points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func rows(for width: CGFloat, subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return (points, CGSize(width: maxX, height: y + rowHeight))
    }
}

#Preview {
    CirclesView(model: HomeModel(), path: .constant([]), onOpenOrbit: {})
}

// MARK: - Invites

/// A real circle's invite code, big enough to read out, with a share button.
struct InviteCard: View {
    let circleName: String
    let code: String

    private var spaced: String { "\(code.prefix(4)) \(code.suffix(4))" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INVITE CODE")
                .font(.pals(13))
                .tracking(1)
                .foregroundStyle(Color.palsInk.opacity(0.5))
            HStack {
                Text(spaced)
                    .font(.palsDisplay(34))
                    .monospaced()
                    .foregroundStyle(Color.palsInk)
                    .textSelection(.enabled)
                    .accessibilityLabel("Invite code \(code.map(String.init).joined(separator: " "))")
                Spacer()
                ShareLink(item: "Join my circle \"\(circleName)\" on Pals! Open Pals, tap Join with a code and enter \(spaced).") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .glassEffect(.regular.tint(.palsBlue).interactive(), in: .circle)
                .accessibilityLabel("Share invite")
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Type a pal's invite code to join their circle.
private struct JoinCircleSheet: View {
    let model: HomeModel
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var joining = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HighlightHeadline(lines: ["Join a"], highlight: "circle", size: 44)
            Text("Type the 8-character code a pal shared with you.")
                .font(.palsBody(16))
                .foregroundStyle(Color.palsInk.opacity(0.65))

            TextField("ABCD 2345", text: $code)
                .font(.palsDisplay(30))
                .monospaced()
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.join)
                .onSubmit(join)
                .padding(.horizontal, 22)
                .frame(height: 64)
                .background(.white, in: Capsule())

            if let error {
                Text(error)
                    .font(.palsBody(14))
                    .foregroundStyle(Color.palsPink)
            }

            Spacer(minLength: 0)

            Button(action: join) {
                Text(joining ? "Joining…" : "Join")
                    .font(.pals(20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.tint(.palsBlue.opacity(canJoin ? 1 : 0.4)).interactive(canJoin), in: .capsule)
            .disabled(!canJoin)
        }
        .padding(24)
        .background(Color.palsOffWhite.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private var canJoin: Bool { CloudStore.normalized(code).count == 8 && !joining }

    private func join() {
        guard canJoin else { return }
        joining = true
        error = nil
        Task {
            error = await model.joinCircle(code: code)
            joining = false
            if error == nil { dismiss() }
        }
    }
}

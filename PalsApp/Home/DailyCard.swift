import SwiftUI

/// Today's activity as a card drawn from the circle's deck. Until you draw it, it's a face-down
/// pile; tap it and the deck gets riffle-shuffled, then the top card flips over. It stays face up for the day.
struct DailyCardView: View {
    @Bindable var model: HomeModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 shows the back, 180 the face.
    @State private var angle: Double = 0
    @State private var drawing = false
    @State private var lifted = false
    @State private var shuffleTicks = 0
    @State private var revealTicks = 0
    /// The face-down cards under today's card, which get shuffled.
    @State private var deck = DeckCard.squared
    /// The whole deck shrinks a little while it's being shuffled, so both halves fit on screen.
    @State private var shuffling = false
    @State private var width: CGFloat = 350

    private var circle: PalsCircle { model.selectedCircle }
    private var revealed: Bool { model.isRevealed(circle) }
    private static let height: CGFloat = 214

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // The rest of the deck, peeking out behind (and shuffled on a draw).
                ForEach(deck) { card in
                    CardBack(showsPrompt: false)
                        .frame(height: Self.height)
                        .scaleEffect(card.scale)
                        .rotationEffect(.degrees(card.angle))
                        .offset(x: card.x * width, y: card.y)
                        .zIndex(card.z)
                        .brightness(revealed ? -0.12 : 0)
                }

                Button {
                    if revealed { model.startActivity() } else { draw() }
                } label: {
                FlipCard(
                    angle: angle,
                    front: CardFace(activity: circle.today, circle: circle,
                                    people: model.peopleDone(in: circle),
                                    done: model.doneCount(in: circle),
                                    total: circle.friends.count + 1,
                                    youDone: model.isDone(in: circle)),
                    back: CardBack(showsPrompt: !drawing)
                )
                .frame(height: Self.height)
                .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .scaleEffect(lifted ? 1.04 : 1)
                .offset(y: lifted ? -8 : 0)
                // While the deck is shuffled, today's card is one of the shuffled cards.
                .opacity(shuffling ? 0 : 1)
                .zIndex(1000)
            }
            .scaleEffect(shuffling ? 0.74 : 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .padding(.bottom, 14)

            if !revealed {
                Text(drawing ? "Shuffling…" : "Tap the deck to draw today's card")
                    .font(.pals(14))
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.opacity)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shuffleTicks)
        .sensoryFeedback(.success, trigger: revealTicks)
        .onAppear { angle = revealed ? 180 : 0 }
        .onChange(of: model.selectedCircleID) {
            // Another circle's deck: show it as it is, no animation.
            angle = revealed ? 180 : 0
            deck = DeckCard.squared
            shuffling = false
            lifted = false
        }
        .onChange(of: model.drawRequests) { draw() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(revealed ? "Today's card: \(circle.today.title)" : "Today's card, face down")
        .accessibilityHint(revealed ? "Starts today's activity" : "Draws today's card")
        .accessibilityAddTraits(.isButton)
    }

    private func draw() {
        guard !revealed, !drawing else { return }
        drawing = true
        let drawnCircle = circle
        Task {
            if !reduceMotion {
                await riffle()
                withAnimation(Motion.select) { lifted = true }
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(Motion.flip) { angle = 180 }
                try? await Task.sleep(for: .milliseconds(450))
                withAnimation(Motion.expand) { lifted = false }
            } else {
                angle = 180
            }
            revealTicks += 1
            model.reveal(drawnCircle)
            drawing = false
        }
    }

    /// A riffle shuffle, twice: cut the deck into two halves, then let the cards fall back
    /// into one pile, alternating sides, one at a time. Then square it up.
    private func riffle() async {
        withAnimation(Motion.select) { shuffling = true }
        try? await Task.sleep(for: .milliseconds(120))

        var top = Double(deck.count)
        for round in 0..<2 {
            // Cut: the bottom half goes left, the top half goes right.
            let order = deck.indices.sorted { deck[$0].z < deck[$1].z }
            let half = order.count / 2
            let left = Array(order[..<half]), right = Array(order[half...])
            withAnimation(Motion.shuffle) {
                for (n, i) in left.enumerated() { deck[i].place(side: -1, height: n) }
                for (n, i) in right.enumerated() { deck[i].place(side: 1, height: n) }
            }
            shuffleTicks += 1
            try? await Task.sleep(for: .milliseconds(round == 0 ? 260 : 200))

            // Riffle: the top card of each half drops onto the middle pile, taking turns.
            var piles = [left, right].map { Array($0.reversed()) }
            var side = round % 2
            var landed = 0
            while !piles[0].isEmpty || !piles[1].isEmpty {
                if piles[side].isEmpty { side = 1 - side }
                let i = piles[side].removeFirst()
                top += 1
                withAnimation(.spring(duration: 0.18, bounce: 0.1)) {
                    deck[i].land(height: landed, z: top)
                }
                landed += 1
                shuffleTicks += 1
                side = 1 - side
                try? await Task.sleep(for: .milliseconds(round == 0 ? 55 : 45))
            }
            try? await Task.sleep(for: .milliseconds(120))
        }

        // Square up: tap the deck straight, then grow back to size.
        withAnimation(Motion.select) {
            let order = deck.indices.sorted { deck[$0].z < deck[$1].z }
            for (n, i) in order.enumerated() { deck[i].square(position: n) }
            shuffling = false
        }
        shuffleTicks += 1
        try? await Task.sleep(for: .milliseconds(260))
    }
}

// MARK: - Deck

/// One face-down card in the deck under today's card. `x` is a share of the card's width.
private struct DeckCard: Identifiable {
    let id: Int
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var scale: CGFloat = 1
    var z: Double

    static let count = 6
    /// A little tilt per card, so the pile looks hand-stacked rather than perfect.
    private static let tilt: [Double] = [-3, 2, -1.5, 2.5, -2, 1]

    /// The resting deck: a pile peeking out under today's card.
    static var squared: [DeckCard] {
        (0..<count).map { var card = DeckCard(id: $0, z: Double($0)); card.square(position: $0); return card }
    }

    /// Resting in the pile; `position` 0 is the bottom.
    mutating func square(position: Int) {
        let fromTop = CGFloat(Self.count - position)
        x = 0
        y = fromTop * 3.5
        angle = Self.tilt[position % Self.tilt.count]
        scale = 1 - fromTop * 0.015
    }

    /// In one half of a cut deck. `side` is -1 (left) or 1 (right); `height` counts up the half.
    mutating func place(side: CGFloat, height: Int) {
        x = side * 0.23
        y = 6 - CGFloat(height) * 2.5
        angle = Double(side) * 7 + Double(height) * 0.4 * Double(side)
        scale = 1
    }

    /// Dropped onto the middle pile during the riffle.
    mutating func land(height: Int, z: Double) {
        x = (id.isMultiple(of: 2) ? -1 : 1) * 0.012
        y = 4 - CGFloat(height) * 1.5
        angle = Self.tilt[id % Self.tilt.count] * 0.6
        scale = 1
        self.z = z
    }
}

// MARK: - Flip

/// Shows `back` until the card has turned half way, then `front` (un-mirrored), turning in 3D.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            back
                .modifier(Turn(degrees: angle))
                .opacity(angle < 90 ? 1 : 0)
            front
                .modifier(Turn(degrees: angle - 180))
                .opacity(angle >= 90 ? 1 : 0)
        }
    }
}

/// A 3D turn around the vertical axis, applied only while the card is actually turned:
/// Liquid Glass renders badly inside a 3D transform, even an identity one.
private struct Turn: ViewModifier {
    let degrees: Double

    func body(content: Content) -> some View {
        if degrees == 0 {
            content
        } else {
            content.rotation3DEffect(.degrees(degrees), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
        }
    }
}

// MARK: - Faces

/// The back of every card: brand pink with a dotted pattern and a big question mark.
private struct CardBack: View {
    var showsPrompt = true

    var body: some View {
        ZStack {
            CardSurface(color: .palsPink, cornerRadius: 28)
            Canvas { context, size in
                let step: CGFloat = 16
                for x in stride(from: step / 2, to: size.width, by: step) {
                    for y in stride(from: step / 2, to: size.height, by: step) {
                        context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                                     with: .color(.white.opacity(0.18)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text("?")
                .font(.palsDisplay(72))
                .foregroundStyle(Color.palsPink)
                .frame(width: 112, height: 112)
                .background(.white, in: Circle())

            VStack {
                HStack {
                    Text("TODAY'S CARD")
                    Spacer()
                }
                Spacer()
            }
            .font(.pals(12))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.85))
            .padding(20)
            .opacity(showsPrompt ? 1 : 0.6)
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }
}

/// The face of a card: the activity on its own colour, with big bold shapes behind it.
private struct CardFace: View {
    let activity: CircleActivity
    let circle: PalsCircle
    let people: [Friend]
    let done: Int
    let total: Int
    let youDone: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            CardSurface(color: activity.cardColor, pattern: activity.cardPattern, cornerRadius: 28)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("TODAY · \(circle.name.uppercased())")
                        .font(.pals(12))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    if youDone {
                        Label("Done", systemImage: "checkmark")
                            .font(.pals(13, weight: .bold))
                            .foregroundStyle(activity.cardColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white, in: Capsule())
                    }
                }

                Spacer(minLength: 8)

                Text(activity.emoji)
                    .font(.system(size: 44))
                Text(activity.title)
                    .font(.palsDisplay(28))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 2)

                HStack(spacing: 10) {
                    Label(activity.durationLabel, systemImage: activity.minutes == nil ? "checkmark.circle" : "timer")
                        .font(.pals(13))
                    MiniAvatars(people: people, size: 22, glass: false)
                    Spacer()
                    Text("\(done)/\(total) done")
                        .font(.pals(13, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 10)
            }
            .padding(20)
        }
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }
}

/// Bold abstract shapes on the right of a card, one of a few patterns per activity.
struct CardArt: View {
    let pattern: Int

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let tint = Color.white.opacity(0.2)
            ZStack(alignment: .trailing) {
                switch pattern {
                case 0:
                    // Two big overlapping circles.
                    Circle().fill(tint).frame(width: h * 1.0).offset(x: h * 0.28, y: -h * 0.05)
                    Circle().fill(tint).frame(width: h * 0.75).offset(x: -h * 0.42, y: h * 0.12)
                case 1:
                    // Three half-moons in a row.
                    ForEach(0..<3, id: \.self) { i in
                        HalfDisc().fill(tint)
                            .frame(width: h * 0.42, height: h * 0.84)
                            .offset(x: -CGFloat(i) * h * 0.34 + h * 0.05)
                    }
                default:
                    // A thick ring with a dot.
                    Circle().stroke(tint, lineWidth: h * 0.16).frame(width: h * 0.95).offset(x: h * 0.3)
                    Circle().fill(tint).frame(width: h * 0.22).offset(x: -h * 0.55, y: -h * 0.24)
                }
            }
            .frame(width: proxy.size.width, height: h, alignment: .trailing)
        }
    }
}

struct HalfDisc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.midY), radius: rect.height / 2,
                    startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Card look per activity

extension CircleActivity {
    /// Stable per title, so an activity's card always looks the same for everyone.
    private var cardSeed: Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in title.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3 }
        return Int(hash % 1_000_003)
    }

    var cardColor: Color {
        let palette: [UInt32] = [0xFF5A36, 0x7B5CFF, 0x14B8A6, 0xFD3D9C, 0x2F80ED, 0x22A06B]
        return Color(hex: palette[cardSeed % palette.count])
    }

    var cardPattern: Int { (cardSeed / 7) % 3 }
}

#Preview {
    DailyCardView(model: HomeModel())
        .padding()
        .background(Color.palsIndigo)
}

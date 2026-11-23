import SwiftUI

// Card-based pieces of the app, all in the same language as today's card:
// every activity is a coloured card with its own bold shapes.

// MARK: - Mini activity card

/// A compact version of an activity's card, for decks and lists.
struct ActivityMiniCard: View {
    let activity: CircleActivity
    var badge: String? = nil
    var note: String? = nil
    var height: CGFloat = 128

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(activity.cardColor)
            CardArt(pattern: activity.cardPattern)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    Text(activity.title)
                        .font(.pals(19, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    if let badge {
                        Text(badge)
                            .font(.pals(12, weight: .bold))
                            .foregroundStyle(activity.cardColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.white, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    Text(activity.emoji)
                        .font(.system(size: 34))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(activity.durationLabel, systemImage: activity.minutes == nil ? "checkmark.circle" : "timer")
                        if let note { Text(note) }
                    }
                    .font(.pals(12))
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(16)
        }
        .frame(height: height)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Pool as a wallet deck

/// The circle's activity pool as a stack of cards, like a wallet. Tap to fan it open.
struct PoolDeck: View {
    let pool: [CircleActivity]
    let todayID: CircleActivity.ID?

    @State private var open = false

    /// Today's card on top, the rest behind it.
    private var ordered: [CircleActivity] {
        pool.sorted { a, _ in a.id == todayID }
    }

    private let cardHeight: CGFloat = 128
    private var step: CGFloat { open ? cardHeight + 10 : 34 }

    var body: some View {
        let cards = ordered
        ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, activity in
                // Back cards first (higher in the stack), today's card in front at the bottom.
                let position = cards.count - 1 - index
                ActivityMiniCard(activity: activity,
                                 badge: activity.id == todayID ? "Today" : nil,
                                 note: "by \(activity.addedBy)",
                                 height: cardHeight)
                    .offset(y: CGFloat(position) * step)
                    .scaleEffect(open ? 1 : 1 - CGFloat(index) * 0.03, anchor: .top)
                    .zIndex(Double(cards.count - index))
            }
        }
        .frame(height: cardHeight + CGFloat(max(0, cards.count - 1)) * step, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.5, bounce: 0.25)) { open.toggle() }
        }
        .sensoryFeedback(.selection, trigger: open)
        .accessibilityElement(children: .contain)
        .accessibilityHint(open ? "Double tap to stack the cards" : "Double tap to fan out the cards")
    }
}

// MARK: - Passions picker

/// Big, colourful pills for choosing a new circle's activities ("pick your passions").
struct PassionPicker: View {
    @Binding var picked: Set<String>

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(CircleActivity.suggestions, id: \.title) { idea in
                pill(idea)
            }
        }
    }

    private func pill(_ idea: CircleActivity) -> some View {
        let isOn = picked.contains(idea.title)
        return Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                if isOn { picked.remove(idea.title) } else { picked.insert(idea.title) }
            }
        } label: {
            HStack(spacing: 10) {
                Text(idea.emoji)
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(isOn ? .white.opacity(0.25) : idea.cardColor.opacity(0.15), in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(idea.cardColor, .white)
                                .offset(x: 4, y: -4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(idea.title)
                    .font(.pals(14, weight: .bold))
                    .foregroundStyle(isOn ? .white : Color.palsInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(8)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
            .background(isOn ? idea.cardColor : .white, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.palsInk.opacity(isOn ? 0 : 0.08), lineWidth: 1))
            .scaleEffect(isOn ? 1 : 0.97)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Category blob

/// A soft cluster of category bubbles. Tap one to see its ideas.
struct CategoryBlob: View {
    @Binding var selected: ActivityCategory?

    /// Bubble centres and sizes in a 340 × 250 space.
    private static let layout: [ActivityCategory: (x: CGFloat, y: CGFloat, d: CGFloat)] = [
        .move: (100, 78, 136), .mind: (222, 66, 124), .body: (285, 160, 112),
        .detox: (66, 176, 108), .social: (178, 176, 132), .chill: (150, 92, 64),
    ]

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / 340
            ZStack {
                // The soft, blended blob.
                ForEach(ActivityCategory.allCases) { category in
                    let spot = Self.layout[category]!
                    Circle()
                        .fill(RadialGradient(colors: [category.color, category.color.opacity(0.75)],
                                             center: .center, startRadius: 0, endRadius: spot.d / 2))
                        .frame(width: spot.d * scale, height: spot.d * scale)
                        .scaleEffect(selected == category ? 1.12 : 1)
                        .opacity(selected == nil || selected == category ? 0.95 : 0.35)
                        .position(x: spot.x * scale, y: spot.y * scale)
                }
                .blur(radius: 6)

                // Labels and tap targets on top, kept sharp.
                ForEach(ActivityCategory.allCases) { category in
                    let spot = Self.layout[category]!
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
                            selected = selected == category ? nil : category
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text(category.emoji).font(.system(size: category == .chill ? 18 : 24))
                            if category != .chill || selected == .chill {
                                Text(category.rawValue).font(.pals(15, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: spot.d * scale * 0.8, height: spot.d * scale * 0.8)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: spot.x * scale, y: spot.y * scale)
                    .accessibilityLabel(category.rawValue)
                    .accessibilityAddTraits(selected == category ? .isSelected : [])
                }
            }
        }
        .aspectRatio(340 / 250, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Prank fan

/// The pranks as a fan of cards; tap one (or swipe) to pull it to the front.
struct PrankFan: View {
    @Binding var selected: PrankKind
    let target: Friend

    private var kinds: [PrankKind] { PrankKind.allCases }
    private var selectedIndex: Int { kinds.firstIndex(of: selected) ?? 0 }

    var body: some View {
        ZStack {
            // A fixed fan centred on the screen; the picked card lifts out to the front.
            ForEach(Array(kinds.enumerated()), id: \.element) { index, kind in
                let spread = Double(index) - Double(kinds.count - 1) / 2
                let isPicked = kind == selected
                card(kind)
                    .scaleEffect(isPicked ? 1 : 0.86)
                    .rotationEffect(.degrees(isPicked ? spread * 3 : spread * 10), anchor: .bottom)
                    .offset(x: spread * 52, y: isPicked ? -18 : abs(spread) * 10)
                    .zIndex(isPicked ? 100 : Double(index))
                    .onTapGesture { pick(kind) }
            }
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { value in
                let next = selectedIndex + (value.translation.width < 0 ? 1 : -1)
                if kinds.indices.contains(next) { pick(kinds[next]) }
            }
        )
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func pick(_ kind: PrankKind) {
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { selected = kind }
    }

    private func card(_ kind: PrankKind) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(kind.cardColor)
            CardArt(pattern: kind.cardPattern)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                PalsAvatar(name: target.name, color: target.color, size: 40, glass: false)
                Spacer()
                Text(kind.emoji).font(.system(size: 64))
                Text(kind.title)
                    .font(.palsDisplay(24))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(16)
        }
        .frame(width: 160, height: 220)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(kind == selected ? [.isButton, .isSelected] : .isButton)
    }
}

extension PrankKind {
    var cardColor: Color {
        switch self {
        case .slap: Color(hex: 0xFF5A36)
        case .egg: Color(hex: 0xF5A524)
        case .italian: Color(hex: 0x22A06B)
        case .iceBucket: Color(hex: 0x2F80ED)
        }
    }

    var cardPattern: Int {
        switch self {
        case .slap: 0
        case .egg: 2
        case .italian: 1
        case .iceBucket: 0
        }
    }
}

// MARK: - Progress: a deck of your days

/// The Progress tab: every day is a card, stacked like a deck. Tap a card to pull it out.
struct ProgressDeckView: View {
    let model: HomeModel

    @State private var openDay: Int?

    private struct Day: Identifiable {
        let id: Int            // days ago
        let date: Date
        let activity: CircleActivity
        let done: Bool
        let prank: PrankKind?
        let hidden: Bool       // today's card not drawn yet
    }

    /// Demo history: the streak's days are done; the day before the streak got skipped (and pranked).
    private var days: [Day] {
        let circle = model.selectedCircle
        let streak = model.streakDays
        let calendar = Calendar.current
        return (0..<min(14, streak + 3)).map { ago in
            let date = calendar.date(byAdding: .day, value: -ago, to: .now) ?? .now
            let done = ago == 0 ? model.isDone(in: circle) : ago <= streak
            let kinds = PrankKind.allCases
            return Day(id: ago, date: date, activity: circle.pick(for: date), done: done,
                       prank: done ? nil : (ago == 0 ? nil : kinds[ago % kinds.count]),
                       hidden: ago == 0 && !model.isRevealed(circle))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HighlightHeadline(lines: ["Your"], highlight: "deck.", size: 52)
                    .padding(.top, 12)

                HStack(spacing: 10) {
                    statPill("🔥 \(model.streakDays) day streak")
                    statPill("🃏 \(days.filter(\.done).count) cards")
                }
                .padding(.top, 12)

                Text("Every day you show up, that day's card goes in your deck. Showing \(model.selectedCircle.name).")
                    .font(.palsBody(15))
                    .foregroundStyle(Color.palsInk.opacity(0.6))
                    .padding(.top, 10)

                deck
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .background(Color.palsOffWhite.ignoresSafeArea())
    }

    private var deck: some View {
        let items = days
        let peek: CGFloat = 58
        let full: CGFloat = 150
        return VStack(spacing: 0) {
            ForEach(items) { day in
                dayCard(day, height: full)
                    .frame(height: openDay == day.id ? full + 12 : peek, alignment: .top)
                    .zIndex(Double(day.id))
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.45, bounce: 0.25)) {
                            openDay = openDay == day.id ? nil : day.id
                        }
                    }
            }
            Color.clear.frame(height: full - peek)
        }
        .sensoryFeedback(.selection, trigger: openDay)
    }

    private func dayCard(_ day: Day, height: CGFloat) -> some View {
        let color: Color = day.hidden ? .palsPink : (day.done ? day.activity.cardColor : Color(white: 0.72))
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color)
            if day.done && !day.hidden {
                CardArt(pattern: day.activity.cardPattern)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 10) {
                // The strip that shows while the card is in the deck.
                HStack(spacing: 10) {
                    Text(day.hidden ? "🃏" : day.activity.emoji).font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(label(for: day).uppercased())
                            .font(.pals(11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(day.hidden ? "Today's card" : day.activity.title)
                            .font(.pals(16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(day.hidden ? "Not drawn" : (day.done ? "Done ✓" : "Skipped"))
                        .font(.pals(12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer(minLength: 0)
                Text(day.hidden ? "Draw it on your Orbit."
                     : (day.done ? "\(day.activity.durationLabel) · added by \(day.activity.addedBy)"
                                 : "You skipped this one."))
                    .font(.palsBody(14))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(16)

            // A stamp on the days you got pranked.
            if let prank = day.prank {
                Text(prank.emoji)
                    .font(.system(size: 30))
                    .padding(10)
                    .background(.white, in: Circle())
                    .rotationEffect(.degrees(-12))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
            }
        }
        .frame(height: height)
        .shadow(color: .black.opacity(0.12), radius: 6, y: -2)
        .accessibilityElement(children: .combine)
    }

    private func label(for day: Day) -> String {
        switch day.id {
        case 0: "Today"
        case 1: "Yesterday"
        default: day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.pals(14, weight: .bold))
            .foregroundStyle(Color.palsInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white, in: Capsule())
    }
}

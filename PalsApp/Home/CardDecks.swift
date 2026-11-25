import SwiftUI

// Card-based pieces of the app, all in the same language as today's card:
// every activity is a coloured card with its own bold shapes.

// MARK: - Card surface

/// The background of every card: its solid colour, with the card's shapes on top.
struct CardSurface: View {
    let color: Color
    var pattern: Int? = nil
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(color)
            if let pattern {
                CardArt(pattern: pattern)
                    .clipShape(shape)
            }
        }
    }
}

// MARK: - Mini activity card

/// A compact version of an activity's card, for decks and lists.
struct ActivityMiniCard: View {
    let activity: CircleActivity
    var badge: String? = nil
    var note: String? = nil
    var height: CGFloat = 128
    /// Shown in the top-right corner, e.g. an edit menu.
    var accessory: AnyView? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            CardSurface(color: activity.cardColor, pattern: activity.cardPattern, cornerRadius: 24)

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
                    if let accessory { accessory }
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

/// The circle's activity pool as a stack of cards, like a wallet. Tap to fan it open. Fanned
/// out, cards you can change get a menu (also on a long press) to edit or delete them.
struct PoolDeck: View {
    let pool: [CircleActivity]
    let todayID: CircleActivity.ID?
    var onEdit: ((CircleActivity) -> Void)? = nil
    var onDelete: ((CircleActivity) -> Void)? = nil

    @State private var open = false

    /// Today's card on top, the rest behind it.
    private var ordered: [CircleActivity] {
        pool.sorted { a, _ in a.id == todayID }
    }

    /// A circle always keeps at least one activity.
    private var canDelete: Bool { pool.count > 1 }

    private let cardHeight: CGFloat = 128
    private var step: CGFloat { open ? cardHeight + 10 : 34 }

    var body: some View {
        let cards = ordered
        ZStack(alignment: .top) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, activity in
                // Back cards first (higher in the stack), today's card in front at the bottom.
                let position = cards.count - 1 - index
                let editable = activity.canEdit && onEdit != nil
                ActivityMiniCard(activity: activity,
                                 badge: activity.id == todayID ? "Today" : nil,
                                 note: "by \(activity.addedBy)",
                                 height: cardHeight,
                                 accessory: open && editable ? AnyView(menu(for: activity)) : nil)
                    .contextMenu {
                        if editable { actions(for: activity) }
                    }
                    .accessibilityActions {
                        if editable {
                            Button("Edit") { onEdit?(activity) }
                            if canDelete { Button("Delete") { onDelete?(activity) } }
                        }
                    }
                    .offset(y: CGFloat(position) * step)
                    .scaleEffect(open ? 1 : 1 - CGFloat(index) * 0.03, anchor: .top)
                    .zIndex(Double(cards.count - index))
            }
        }
        .frame(height: cardHeight + CGFloat(max(0, cards.count - 1)) * step, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.expand) { open.toggle() }
        }
        .sensoryFeedback(.selection, trigger: open)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(open ? "Double tap to stack the cards" : "Double tap to fan out the cards")
    }

    private func menu(for activity: CircleActivity) -> some View {
        Menu {
            actions(for: activity)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.25), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .padding(.top, -8)
        .padding(.trailing, -8)
        .accessibilityLabel("Edit or delete \(activity.title)")
    }

    @ViewBuilder
    private func actions(for activity: CircleActivity) -> some View {
        Button { onEdit?(activity) } label: { Label("Edit", systemImage: "pencil") }
        Button(role: .destructive) { onDelete?(activity) } label: { Label("Delete", systemImage: "trash") }
            .disabled(!canDelete)
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
            withAnimation(Motion.select) {
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
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
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
        .buttonStyle(PressableStyle())
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
                        withAnimation(Motion.expand) {
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
                    .buttonStyle(PressableStyle())
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

// MARK: - Prank picker

/// The pranks as a row of trading cards: the picked one stands upright in the middle, its
/// neighbours lean away behind it. Swipe to move one card at a time, or tap a side card to pick it.
struct PrankPicker: View {
    @Binding var selected: PrankKind

    /// How far the row is being dragged, in cards (positive = towards the next card).
    @State private var drag: CGFloat = 0
    @State private var width: CGFloat = 400

    private let kinds = PrankKind.allCases
    private var index: Int { kinds.firstIndex(of: selected) ?? 0 }
    private var cardWidth: CGFloat { width * 0.54 }
    /// Distance between neighbouring cards' centres.
    private var spacing: CGFloat { cardWidth * 0.8 }

    var body: some View {
        VStack(spacing: 10) {
            // Points at the picked card.
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 14))
                .foregroundStyle(selected.cardColor)

            ZStack {
                ForEach(Array(kinds.enumerated()), id: \.element) { i, kind in
                    // Where this card sits relative to the middle, in cards.
                    let offset = CGFloat(i - index) - drag
                    let near = min(abs(offset), 1)
                    PrankCard(kind: kind)
                        .frame(width: cardWidth)
                        .brightness(-near * 0.04)
                        .scaleEffect(1 - near * 0.1)
                        .rotationEffect(.degrees(Double(max(-1.6, min(1.6, offset))) * 10), anchor: .bottom)
                        .offset(x: offset * spacing, y: near * 18)
                        .opacity(abs(offset) > 2.2 ? 0 : 1)
                        .zIndex(-Double(abs(offset)))
                        .onTapGesture { pick(i) }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(kind.title). \(kind.pitch)")
                        .accessibilityAddTraits(kind == selected ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { pick(i) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        var moved = -value.translation.width / spacing
                        // Stretchy at the ends.
                        if (index == 0 && moved < 0) || (index == kinds.count - 1 && moved > 0) { moved *= 0.3 }
                        drag = moved
                    }
                    .onEnded { value in
                        let flung = -value.predictedEndTranslation.width / spacing
                        // One card per swipe, so it's easy to land where you want.
                        let step = flung > 0.35 ? 1 : (flung < -0.35 ? -1 : 0)
                        let target = max(0, min(kinds.count - 1, index + step))
                        withAnimation(Motion.expand) {
                            drag = 0
                            selected = kinds[target]
                        }
                    }
            )
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func pick(_ i: Int) {
        withAnimation(Motion.expand) { selected = kinds[i] }
    }
}

/// One prank as a trading card: its name, a big picture, and what it does.
private struct PrankCard: View {
    let kind: PrankKind

    var body: some View {
        VStack(spacing: 10) {
            Text(kind.title)
                .font(.palsDisplay(22))
                .foregroundStyle(Color.palsInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ZStack {
                CardSurface(color: kind.cardColor, pattern: kind.cardPattern, cornerRadius: 16)
                Text(kind.emoji)
                    .font(.system(size: 92))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 8)
            }
            .aspectRatio(1.1, contentMode: .fit)

            Text(kind.pitch)
                .font(.palsBody(13))
                .foregroundStyle(Color.palsInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
        }
        .padding(12)
        .background(Color(hex: 0xFFFBEA), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(kind.cardColor, lineWidth: 6)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                HighlightHeadline(lines: ["Your"], highlight: "deck", size: 52,
                    info: "Every day you show up, that day's card goes in your deck. Showing \(model.selectedCircle.name).")
                    .padding(.top, 12)

                HStack(spacing: 10) {
                    statPill("🔥 \(model.streakDays) day streak")
                    statPill("🃏 \(days.filter(\.done).count) cards")
                }
                .padding(.top, 12)

                deck
                    .padding(.top, 24)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        // Pull down to sync with iCloud now.
        .refreshable { await model.refresh() }
        .background(Color.palsOffWhite.ignoresSafeArea())
    }

    private var deck: some View {
        let items = days
        let peek: CGFloat = 58
        let full: CGFloat = 150
        return VStack(spacing: 0) {
            ForEach(items) { day in
                Button {
                    withAnimation(Motion.expand) {
                        openDay = openDay == day.id ? nil : day.id
                    }
                } label: {
                    dayCard(day, height: full)
                }
                .buttonStyle(PressableStyle())
                .frame(height: openDay == day.id ? full + 12 : peek, alignment: .top)
                .zIndex(Double(day.id))
            }
            Color.clear.frame(height: full - peek)
        }
        .sensoryFeedback(.selection, trigger: openDay)
    }

    private func dayCard(_ day: Day, height: CGFloat) -> some View {
        let color: Color = day.hidden ? .palsPink : (day.done ? day.activity.cardColor : Color(white: 0.72))
        return ZStack(alignment: .topLeading) {
            CardSurface(color: color, pattern: day.done && !day.hidden ? day.activity.cardPattern : nil,
                        cornerRadius: 24)
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

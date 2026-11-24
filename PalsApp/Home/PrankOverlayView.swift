import Metal
import SwiftUI

/// Full-screen prank that plays when you open the app after skipping your activity:
/// big emoji play out on a face: a slap, an egg on the head, or the Italian "ma che fai?!" hand.
struct PrankOverlayView: View {
    enum Stage { case incoming, impact, aftermath }

    let prank: IncomingPrank
    var onImpact: () -> Void
    var onStartActivity: () -> Void
    var onDismiss: () -> Void

    @State private var stage: Stage = .incoming
    @State private var showCard = false
    @State private var shakes: CGFloat = 0
    /// When the hit landed, for the shockwave; nil when none is running.
    @State private var impactStart: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            scene
                .modifier(ShakeEffect(animatableData: shakes))
                .modifier(ImpactWave(start: impactStart, point: impactPoint))
                .ignoresSafeArea()

            if showCard {
                VStack {
                    Spacer()
                    card
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await play() }
        .accessibilityAddTraits(.isModal)
    }

    /// Where the shockwave starts, as a fraction of the screen: the slapped cheek, or the top of the head.
    private var impactPoint: UnitPoint {
        switch prank.kind {
        case .slap: UnitPoint(x: 0.62, y: 0.37)
        case .egg: UnitPoint(x: 0.5, y: 0.27)
        case .italian: UnitPoint(x: 0.66, y: 0.42)
        case .iceBucket: UnitPoint(x: 0.5, y: 0.24)
        }
    }

    /// Everything that shakes and ripples: the dimming and the animation. (Shaders can't draw the
    /// system's UIKit-backed views like the tab bar, so the live app underneath is left alone.)
    private var scene: some View {
        ZStack {
            // Dim the app so the face is the subject.
            Color.black
                .opacity(stage == .incoming ? 0.45 : 0.6)
                .ignoresSafeArea()

            EmojiPrankAnimation(kind: prank.kind, stage: stage,
                                face: prank.kind == .italian ? prank.pranker : prank.victim)

            if stage != .incoming {
                impactWord
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    private func play() async {
        // The hand / egg starts moving on appear; wait for it to land.
        let landsAfter = switch prank.kind {
        case .slap: 0.45
        case .egg: 0.6
        case .italian: 0.4
        case .iceBucket: 0.5
        }
        PrankHaptics.shared.play(prank.kind, impactAt: landsAfter)
        try? await Task.sleep(for: .seconds(landsAfter))
        withAnimation(Motion.pop) { stage = .impact }
        onImpact()
        if !reduceMotion {
            impactStart = .now
            withAnimation(Motion.shake) { shakes += 1 }
        }
        try? await Task.sleep(for: .milliseconds(750))
        withAnimation(.easeOut(duration: 0.4)) { stage = .aftermath }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(Motion.sheet) { showCard = true }
        try? await Task.sleep(for: .milliseconds(400))
        impactStart = nil
    }

    private var impactWord: some View {
        Text(prank.kind.sound)
            .font(.palsDisplay(76))
            .tracking(-2)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .background(Color.palsPink.rotationEffect(.degrees(-4)))
            .overlay(alignment: .topTrailing) {
                BurstMarks()
                    .offset(x: 48, y: -44)
            }
            .rotationEffect(.degrees(-8))
            .scaleEffect(prank.kind == .italian ? 0.6 : 0.85)
            // Above the face, clear of the emoji and of the card that slides up later.
            .offset(y: -300)
            .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                // "You" when previewing: show your own photo, not a "Y".
                (prank.fromName == "You" ? PrankFace.you : PrankFace(name: prank.fromName, color: prank.fromColor, isYou: false))
                    .sized(54)
                VStack(alignment: .leading, spacing: 2) {
                    if let target = prank.sentTo {
                        Text("\(target) got \(prank.kind.pastTense)! \(prank.kind.emoji)")
                            .font(.palsDisplay(26))
                        Text("They'll get this the next time they open Pals.")
                            .font(.palsBody(15))
                            .foregroundStyle(Color.palsInk.opacity(0.65))
                    } else if let target = prank.previewTarget {
                        Text("This is what \(target) will see 👀")
                            .font(.palsDisplay(24))
                        Text("Sent the moment you tap send.")
                            .font(.palsBody(15))
                            .foregroundStyle(Color.palsInk.opacity(0.65))
                    } else {
                        Text(prank.kind.receivedLine(from: prank.fromName))
                            .font(.palsDisplay(26))
                        Text(prank.reason)
                            .font(.palsBody(15))
                            .foregroundStyle(Color.palsInk.opacity(0.65))
                    }
                }
                .foregroundStyle(Color.palsInk)
            }

            if prank.sentTo != nil {
                primaryButton("Muahaha", systemImage: "checkmark", action: onDismiss)
            } else if prank.previewTarget != nil {
                primaryButton("Ha, got it", systemImage: "checkmark", action: onDismiss)
            } else {
                primaryButton("Okay okay, I'm on it", systemImage: "play.fill", action: onStartActivity)
                Button("I'll take the hit", action: onDismiss)
                    .font(.pals(16))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.palsOffWhite)
                .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .fontWeight(.heavy)
                Text(title)
            }
            .font(.pals(20, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
    }
}

// MARK: - Emoji animations

/// The prank played with big emoji around a face (yours for the slap and egg, your pal's for "ma che fai").
private struct EmojiPrankAnimation: View {
    let kind: PrankKind
    let stage: PrankOverlayView.Stage
    let face: PrankFace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var pumped = false
    /// The empty bucket is pulled back out of frame once it has poured.
    @State private var bucketGone = false

    private var hit: Bool { stage != .incoming }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let center = CGPoint(x: w / 2, y: proxy.size.height * 0.36)
            ZStack {
                faceView
                    .position(center)

                switch kind {
                case .slap: slap(width: w)
                    .position(x: center.x + 95, y: center.y + 10)
                case .egg: egg
                    .position(x: center.x, y: center.y - 95)
                case .italian: italian
                    .position(x: center.x + 110, y: center.y + 60)
                case .iceBucket: iceBucket(center: center, height: proxy.size.height)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(kind == .egg ? .easeIn(duration: 0.55).delay(0.05)
                                       : .easeIn(duration: 0.38).delay(0.05)) { arrived = true }
        }
        .onChange(of: stage) { _, newValue in
            if kind == .iceBucket, newValue == .aftermath {
                withAnimation(.easeOut(duration: 0.3).delay(0.4)) { bucketGone = true }
            }
            guard kind == .italian, newValue == .impact, !reduceMotion else { return }
            // Pump the wrist in time with the haptic taps (0.36 s per pump).
            withAnimation(.easeInOut(duration: 0.18).repeatCount(9, autoreverses: true)) { pumped = true }
        }
    }

    /// The face the prank happens to, reacting on impact.
    private var faceView: some View {
        face.sized(170)
            .rotationEffect(.degrees(kind == .slap && hit ? -16 : 0))
            .offset(x: kind == .slap && hit ? -24 : 0)
            .scaleEffect(x: kind == .egg && hit ? 1.06 : 1, y: kind == .egg && hit ? 0.92 : 1, anchor: .bottom)
            .rotationEffect(.degrees(kind == .italian ? (pumped ? -4 : 3) : 0))
            .overlay {
                // Soaked and frozen: an icy tint over the face.
                if kind == .iceBucket, hit {
                    Circle().fill(Color.cyan.opacity(0.3)).padding(8)
                        .transition(.opacity)
                }
            }
            .modifier(Shiver(active: kind == .iceBucket && hit && !reduceMotion))
            .animation(.spring(duration: 0.35, bounce: 0.55), value: hit)
    }

    // MARK: Slap: 🖐️ swings in from the right and lands on the cheek.

    private func slap(width: CGFloat) -> some View {
        ZStack {
            Text("💥")
                .font(.system(size: 90))
                .offset(x: -40, y: -10)
                .scaleEffect(hit ? 1 : 0.1)
                .opacity(hit ? (stage == .aftermath ? 0 : 1) : 0)
                .animation(.spring(duration: 0.3, bounce: 0.6), value: hit)
                .animation(.easeOut(duration: 0.4), value: stage)

            Text("🖐️")
                .font(.system(size: 170))
                .scaleEffect(x: -1, y: 1) // palm facing the face
                .rotationEffect(.degrees(stage == .aftermath ? 30 : (arrived ? -18 : 40)))
                .offset(x: stage == .aftermath ? width : (arrived ? 0 : width), y: arrived ? 0 : -120)
        }
    }

    // MARK: Egg: 🥚 drops onto the head and squashes flat on impact.

    private var egg: some View {
        Text("🥚")
            .font(.system(size: 110))
            .rotationEffect(.degrees(hit ? 0 : (arrived ? 12 : -30)))
            .scaleEffect(x: hit ? 1.45 : 1, y: hit ? 0.45 : 1, anchor: .bottom)
            .offset(y: arrived ? (hit ? 20 : 0) : -420)
            .animation(.spring(duration: 0.3, bounce: 0.45), value: hit)
    }

    // MARK: Ice bucket: 🪣 tips over the head and ice water pours down the whole screen.

    private func iceBucket(center: CGPoint, height: CGFloat) -> some View {
        let mouth = CGPoint(x: center.x + 10, y: center.y - 150)
        return ZStack {
            if hit {
                IcePour(mouth: mouth, bottom: height, animated: !reduceMotion)
                    .transition(.opacity)
            }
            Text("🪣")
                .font(.system(size: 120))
                .rotationEffect(.degrees(hit ? 150 : (arrived ? 20 : 0)))
                .position(x: mouth.x + 40, y: mouth.y - 40)
                .offset(x: arrived && !bucketGone ? 0 : 320, y: arrived && !bucketGone ? 0 : -260)
                .animation(.spring(duration: 0.35, bounce: 0.3), value: hit)
        }
    }

    // MARK: Ma che fai: 🤌 rises next to your pal's face and pumps.

    private var italian: some View {
        Text("🤌")
            .font(.system(size: 150))
            .rotationEffect(.degrees(pumped ? -14 : 6), anchor: .bottom)
            .offset(y: pumped ? -18 : 0)
            .offset(y: arrived ? 0 : 500)
    }
}

/// Ice water pouring from the bucket's mouth to the bottom of the screen: a pale blue sheet of
/// water plus ice cubes and drops tumbling through it.
private struct IcePour: View {
    let mouth: CGPoint
    let bottom: CGFloat
    let animated: Bool

    @State private var start = Date.now

    private struct Bit {
        let emoji: String
        let spread: CGFloat   // how far sideways it drifts, -1...1
        let delay: Double
        let size: CGFloat
        let spin: Double
    }

    /// Fixed so every pour looks the same.
    private static let bits: [Bit] = (0..<26).map { i in
        let r = Double((i * 37) % 26) / 26
        return Bit(emoji: i.isMultiple(of: 3) ? "💧" : "🧊",
                   spread: CGFloat(((i * 53) % 21) - 10) / 10,
                   delay: Double(i) * 0.045,
                   size: 30 + CGFloat((i * 13) % 4) * 8,
                   spin: (r - 0.5) * 540)
    }

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = animated ? context.date.timeIntervalSince(start) : 1.0
            let fill = min(1, t / 0.45)
            ZStack {
                // The sheet of water, widening as it falls.
                Path { path in
                    let y = mouth.y + (bottom - mouth.y) * fill
                    let spread = 60 + 140 * fill
                    path.move(to: CGPoint(x: mouth.x - 30, y: mouth.y))
                    path.addLine(to: CGPoint(x: mouth.x + 30, y: mouth.y))
                    path.addLine(to: CGPoint(x: mouth.x + spread, y: y))
                    path.addLine(to: CGPoint(x: mouth.x - spread, y: y))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(hex: 0x7FD3FF).opacity(0.75), Color(hex: 0x3BA7F5).opacity(0.35)],
                                     startPoint: .top, endPoint: .bottom))
                .opacity(t < 1.6 ? 1 : max(0, 1 - (t - 1.6) * 2))

                ForEach(Self.bits.indices, id: \.self) { i in
                    let bit = Self.bits[i]
                    let p = max(0, t - bit.delay)
                    let y = mouth.y + 900 * p * p + 260 * p
                    if animated, p > 0, y < bottom + 60 {
                        Text(bit.emoji)
                            .font(.system(size: bit.size))
                            .rotationEffect(.degrees(bit.spin * p))
                            .position(x: mouth.x + bit.spread * 140 * min(1, p * 1.6), y: y)
                    }
                }
            }
        }
        .onAppear { start = .now }
        .allowsHitTesting(false)
    }
}

/// A quick cold shiver: tiny, fast side-to-side jitter.
private struct Shiver: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            content.offset(x: active ? sin(t * 70) * 3 : 0)
        }
    }
}

/// Horizontal shake for the whole screen on impact. Animate `animatableData` by +1.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 8) * 14, y: 0))
    }
}

#Preview("Slap") {
    PrankOverlayView(prank: IncomingPrank(kind: .slap, fromName: "Pasquale", fromColor: .palsIndigo),
                     onImpact: {}, onStartActivity: {}, onDismiss: {})
        .background(Color.palsOffWhite)
}

#Preview("Egg") {
    PrankOverlayView(prank: IncomingPrank(kind: .egg, fromName: "Pasquale", fromColor: .palsIndigo),
                     onImpact: {}, onStartActivity: {}, onDismiss: {})
        .background(Color.palsOffWhite)
}

/// Runs the `impactWave` Metal shader over the view for a moment after `start`.
struct ImpactWave: ViewModifier {
    let start: Date?
    let point: UnitPoint

    /// SwiftUI draws a placeholder over the whole view if a shader is missing, so only use it
    /// when it's really compiled into the app. Checked once, so the view tree never changes shape.
    private static let shaderAvailable: Bool = {
        MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()?.functionNames.contains("impactWave") ?? false
    }()

    func body(content: Content) -> some View {
        if Self.shaderAvailable {
            TimelineView(.animation(paused: start == nil)) { context in
                let time = start.map { context.date.timeIntervalSince($0) } ?? 99
                content.visualEffect { view, proxy in
                    view.layerEffect(
                        ShaderLibrary.impactWave(
                            .float2(proxy.size.width * point.x, proxy.size.height * point.y),
                            .float(time),
                            .float(48)
                        ),
                        maxSampleOffset: CGSize(width: 60, height: 60),
                        isEnabled: time < 1.3
                    )
                }
            }
        } else {
            content
        }
    }
}

#Preview("Ma che fai") {
    PrankOverlayView(prank: IncomingPrank(kind: .italian, fromName: "Pasquale", fromColor: .palsIndigo),
                     onImpact: {}, onStartActivity: {}, onDismiss: {})
        .background(Color.palsOffWhite)
}

#Preview("Ice bucket") {
    PrankOverlayView(prank: IncomingPrank(kind: .iceBucket, fromName: "Pasquale", fromColor: .palsIndigo),
                     onImpact: {}, onStartActivity: {}, onDismiss: {})
        .background(Color.palsOffWhite)
}


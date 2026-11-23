import Metal
import SwiftUI

/// Full-screen prank that plays when you open the app after skipping your activity:
/// a sketched pal slaps you across the face, or an egg falls and cracks on top of the screen.
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
        prank.kind == .slap ? UnitPoint(x: 0.44, y: 0.39) : UnitPoint(x: 0.5, y: 0.2)
    }

    /// Everything that shakes and ripples: the dimming and the animation. (Shaders can't draw the
    /// system's UIKit-backed views like the tab bar, so the live app underneath is left alone.)
    private var scene: some View {
        ZStack {
            // The egg scene has no paper behind it, so dim the app more to make its face the subject.
            Color.black
                .opacity(prank.kind == .egg ? (stage == .incoming ? 0.5 : 0.62)
                                            : (stage == .incoming ? 0.12 : 0.3))
                .ignoresSafeArea()

            switch prank.kind {
            case .slap: SlapAnimation(stage: stage, pranker: prank.pranker, victim: prank.victim)
            case .egg: EggAnimation(stage: stage, victim: prank.victim)
            }

            if stage != .incoming {
                impactWord
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }
        }
    }

    private func play() async {
        // The hand / egg starts moving on appear; wait for it to land.
        let landsAfter = prank.kind == .slap ? 0.45 : 0.65
        PrankHaptics.shared.play(prank.kind, impactAt: landsAfter)
        try? await Task.sleep(for: .seconds(landsAfter))
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { stage = .impact }
        onImpact()
        if !reduceMotion {
            impactStart = .now
            withAnimation(.linear(duration: 0.45)) { shakes += 1 }
        }
        try? await Task.sleep(for: .milliseconds(750))
        withAnimation(.easeOut(duration: 0.4)) { stage = .aftermath }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showCard = true }
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
            .scaleEffect(prank.kind == .slap ? 0.7 : 1)
            .offset(y: prank.kind == .slap ? -310 : 10)
            .accessibilityHidden(true)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                PalsAvatar(name: prank.fromName, color: prank.fromColor, size: 54)
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
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
    }
}

// MARK: - Slap

/// A sketch on a sheet of paper with real faces: your pal winds up and slaps you across the face,
/// with motion streaks, an impact star, a red cheek and speed lines.
private struct SlapAnimation: View {
    let stage: PrankOverlayView.Stage
    let pranker: PrankFace
    let victim: PrankFace

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Arm angle around the shoulder; 0° points right, more negative swings over the top to the left.
    @State private var swing: Double = -25

    private static let impactAngle: Double = -196

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 32, 400)
            let height = width * 0.86
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(white: 0.985))
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

                SketchSlapScene(pranker: pranker, victim: victim,
                                swing: swing,
                                hit: stage != .incoming,
                                settled: stage == .aftermath)
                    .frame(width: 320, height: 280)
                    .scaleEffect(width / 340)
            }
            .frame(width: width, height: height)
            .rotationEffect(.degrees(-2))
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.36)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else {
                swing = Self.impactAngle
                return
            }
            // Wind up a little further back, then swing over the top into the face.
            withAnimation(.easeOut(duration: 0.14)) { swing = -55 }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeIn(duration: 0.24)) { swing = Self.impactAngle }
        }
        .onChange(of: stage) { _, newValue in
            if newValue == .aftermath, !reduceMotion {
                // A small follow-through recoil after the hit.
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) { swing = Self.impactAngle + 18 }
            }
        }
    }
}

/// The drawing itself, in a 320 × 280 canvas. Everything is black "charcoal" line art.
private struct SketchSlapScene: View {
    let pranker: PrankFace
    let victim: PrankFace
    let swing: Double
    let hit: Bool
    let settled: Bool

    private let shoulder = CGPoint(x: 235, y: 140)
    private let face = CGPoint(x: 90, y: 175)

    var body: some View {
        ZStack {
            // Motion streaks along the arm's path, just before the face.
            ForEach(0..<4, id: \.self) { i in
                Path { path in
                    path.addArc(center: shoulder, radius: 78 + CGFloat(i) * 11,
                                startAngle: .degrees(-120), endAngle: .degrees(-190), clockwise: true)
                }
                .stroke(Color.black.opacity(0.18 + Double(i) * 0.07),
                        style: StrokeStyle(lineWidth: 9 - CGFloat(i), lineCap: .round))
            }
            .opacity(hit && !settled ? 1 : 0)
            .animation(.easeOut(duration: settled ? 0.5 : 0.08), value: settled)

            victimFigure
                .offset(x: hit ? -16 : 0, y: hit ? 4 : 0)
                .rotationEffect(.degrees(hit ? -14 : 0), anchor: UnitPoint(x: 90 / 320, y: 1))
                .animation(.spring(duration: 0.35, bounce: 0.55), value: hit)

            prankerFigure

            arm
                .rotationEffect(.degrees(swing), anchor: UnitPoint(x: shoulder.x / 320, y: shoulder.y / 280))

            // Impact star on the cheek.
            ImpactStar()
                .sketched(lineWidth: 3)
                .frame(width: 46, height: 46)
                .position(x: 138, y: 166)
                .scaleEffect(hit ? 1 : 0.2, anchor: UnitPoint(x: 138 / 320, y: 166 / 280))
                .opacity(hit ? (settled ? 0.7 : 1) : 0)
                .animation(.spring(duration: 0.3, bounce: 0.6), value: hit)
        }
        .frame(width: 320, height: 280)
    }

    // MARK: The one getting slapped (left)

    private var victimFigure: some View {
        ZStack {
            // Head (their real face) and drawn shoulders.
            victim.sized(92)
                .overlay(Circle().sketched(lineWidth: 3))
                .position(face)
            Path { path in
                path.move(to: CGPoint(x: 30, y: 280))
                path.addQuadCurve(to: CGPoint(x: 70, y: 226), control: CGPoint(x: 36, y: 236))
                path.move(to: CGPoint(x: 112, y: 224))
                path.addQuadCurve(to: CGPoint(x: 160, y: 280), control: CGPoint(x: 150, y: 232))
            }
            .sketched()

            // A red handprint blush on the slapped cheek.
            Ellipse()
                .fill(Color.palsPink.opacity(0.55))
                .frame(width: 34, height: 22)
                .rotationEffect(.degrees(-20))
                .position(x: 118, y: 186)
                .opacity(hit ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: hit)

            // Speed lines flying off behind the head.
            Path { path in
                for (y, length) in [(140.0, 26.0), (156.0, 40.0), (172.0, 32.0), (188.0, 44.0), (204.0, 24.0)] {
                    path.move(to: CGPoint(x: 38 - length, y: y))
                    path.addLine(to: CGPoint(x: 38, y: y))
                }
            }
            .sketched(lineWidth: 4)
            .opacity(hit ? 1 : 0)
            .offset(x: hit ? 0 : 20)
            .animation(.easeOut(duration: 0.2), value: hit)
        }
    }

    // MARK: The one slapping (right)

    private var prankerFigure: some View {
        ZStack {
            pranker.sized(84)
                .overlay(Circle().sketched(lineWidth: 3))
                .position(x: 257, y: 60)
            // Body: a soft blob going down past the bottom edge.
            Path { path in
                path.move(to: CGPoint(x: 226, y: 100))
                path.addQuadCurve(to: CGPoint(x: 218, y: 280), control: CGPoint(x: 210, y: 190))
                path.move(to: CGPoint(x: 290, y: 100))
                path.addQuadCurve(to: CGPoint(x: 300, y: 280), control: CGPoint(x: 312, y: 190))
            }
            .sketched()
        }
    }

    /// Arm drawn pointing right from the shoulder; the whole view rotates around the shoulder.
    private var arm: some View {
        Path { path in
            let x = shoulder.x, y = shoulder.y
            // Upper and lower edge of the arm.
            path.move(to: CGPoint(x: x, y: y - 8)); path.addLine(to: CGPoint(x: x + 82, y: y - 10))
            path.move(to: CGPoint(x: x, y: y + 8)); path.addLine(to: CGPoint(x: x + 82, y: y + 10))
            // Open hand: four fingers and a thumb.
            for (dy, length) in [(-11.0, 22.0), (-4.0, 28.0), (3.0, 28.0), (10.0, 22.0)] {
                path.move(to: CGPoint(x: x + 82, y: y + dy))
                path.addLine(to: CGPoint(x: x + 82 + length, y: y + dy * 1.4))
            }
            path.move(to: CGPoint(x: x + 80, y: y - 12))
            path.addLine(to: CGPoint(x: x + 92, y: y - 26))
        }
        .sketched()
    }
}

/// A spiky comic "pow" star.
private struct ImpactStar: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<16 {
            let radius = i.isMultiple(of: 2) ? outer : outer * 0.45
            let angle = Double(i) / 16 * 2 * .pi - .pi / 2
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private extension Shape {
    /// Charcoal-pencil look: a main black stroke plus a faint, slightly offset second pass.
    func sketched(lineWidth: CGFloat = 4) -> some View {
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        return ZStack {
            stroke(Color.black.opacity(0.82), style: style)
            stroke(Color.black.opacity(0.28), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round, lineJoin: .round))
                .offset(x: 1.2, y: 0.9)
        }
    }
}

// MARK: - Egg

private struct EggAnimation: View {
    let stage: PrankOverlayView.Stage
    let victim: PrankFace
    @State private var falling = false
    @State private var dripping = false

    var body: some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let impactY = proxy.size.height * 0.2

            ZStack {
                // The egg lands on their head.
                victim.sized(132)
                    .rotationEffect(.degrees(stage == .incoming ? 0 : -8))
                    .offset(y: stage == .incoming ? 0 : 10)
                    .position(x: midX, y: impactY + 70)
                    .animation(.spring(duration: 0.35, bounce: 0.5), value: stage)

                if stage == .incoming {
                    Text("🥚")
                        .font(.system(size: 130))
                        .rotationEffect(.degrees(falling ? 15 : -35))
                        .position(x: midX, y: falling ? impactY : -140)
                } else {
                    YolkSplat(dripping: dripping)
                        .frame(width: 300, height: 560)
                        .position(x: midX, y: impactY + 230)
                        .transition(.scale(scale: 0.15, anchor: .top).combined(with: .opacity))

                    shellHalf(top: true)
                        .rotationEffect(.degrees(stage == .aftermath ? -70 : -25))
                        .offset(x: stage == .aftermath ? -170 : -70, y: stage == .aftermath ? -120 : -40)
                        .opacity(stage == .aftermath ? 0 : 1)
                        .position(x: midX, y: impactY)

                    shellHalf(top: false)
                        .rotationEffect(.degrees(stage == .aftermath ? 80 : 30))
                        .offset(x: stage == .aftermath ? 160 : 70, y: stage == .aftermath ? 260 : 10)
                        .opacity(stage == .aftermath ? 0 : 1)
                        .position(x: midX, y: impactY)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 0.6).delay(0.05)) { falling = true }
        }
        .onChange(of: stage) { _, newValue in
            if newValue == .impact {
                withAnimation(.easeIn(duration: 2.8)) { dripping = true }
            }
        }
    }

    private func shellHalf(top: Bool) -> some View {
        Text("🥚")
            .font(.system(size: 110))
            .frame(width: 130, height: 140)
            .mask(alignment: top ? .top : .bottom) {
                Rectangle().frame(height: 70)
            }
    }
}

/// White splat with a yolk in the middle and drips that run down the screen.
private struct YolkSplat: View {
    let dripping: Bool

    private let yolk = LinearGradient(colors: [Color(hex: 0xFFD23F), Color(hex: 0xFFA41B)],
                                      startPoint: .top, endPoint: .bottom)

    var body: some View {
        ZStack(alignment: .top) {
            // Drips (behind the splat).
            HStack(alignment: .top, spacing: 34) {
                drip(width: 22, length: 210)
                drip(width: 30, length: 330)
                drip(width: 18, length: 150)
                drip(width: 26, length: 260)
            }
            .padding(.top, 80)

            // Egg white.
            ZStack {
                Ellipse().frame(width: 250, height: 140)
                Circle().frame(width: 90).offset(x: -110, y: -20)
                Circle().frame(width: 70).offset(x: 115, y: 25)
                Circle().frame(width: 50).offset(x: 40, y: -62)
                Circle().frame(width: 40).offset(x: -60, y: 60)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            .padding(.top, 20)

            // Yolk.
            Circle()
                .fill(yolk)
                .frame(width: 104, height: 104)
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(.white.opacity(0.55))
                        .frame(width: 30, height: 18)
                        .rotationEffect(.degrees(-30))
                        .offset(x: 22, y: 18)
                }
                .padding(.top, 38)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func drip(width: CGFloat, length: CGFloat) -> some View {
        Capsule()
            .fill(yolk)
            .frame(width: width, height: dripping ? length : 20)
            .overlay(alignment: .bottom) {
                Circle()
                    .fill(Color(hex: 0xFFA41B))
                    .frame(width: width * 1.35)
                    .offset(y: width * 0.2)
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


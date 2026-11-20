import SwiftUI

/// Full-screen prank that plays when you open the app after skipping your activity:
/// a hand slaps the screen, or an egg falls and cracks on top of it.
struct PrankOverlayView: View {
    enum Stage { case incoming, impact, aftermath }

    let prank: IncomingPrank
    var onImpact: () -> Void
    var onStartActivity: () -> Void
    var onDismiss: () -> Void

    @State private var stage: Stage = .incoming
    @State private var showCard = false
    @State private var impacts = 0

    var body: some View {
        ZStack {
            Color.black
                .opacity(stage == .incoming ? 0.12 : 0.3)
                .ignoresSafeArea()

            switch prank.kind {
            case .slap: SlapAnimation(stage: stage)
            case .egg: EggAnimation(stage: stage)
            }

            if stage != .incoming {
                impactWord
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            }

            if showCard {
                VStack {
                    Spacer()
                    card
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: impacts)
        .task { await play() }
        .accessibilityAddTraits(.isModal)
    }

    private func play() async {
        // The hand / egg starts moving on appear; wait for it to land.
        try? await Task.sleep(for: .milliseconds(prank.kind == .slap ? 450 : 650))
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { stage = .impact }
        impacts += 1
        onImpact()
        try? await Task.sleep(for: .milliseconds(750))
        withAnimation(.easeOut(duration: 0.4)) { stage = .aftermath }
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showCard = true }
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
            .offset(y: prank.kind == .slap ? -170 : 10)
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

private struct SlapAnimation: View {
    let stage: PrankOverlayView.Stage
    @State private var arrived = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                // Red sting where the hand landed.
                RadialGradient(colors: [Color.palsPink.opacity(0.6), .clear],
                               center: .center, startRadius: 10, endRadius: 280)
                    .opacity(stage == .incoming ? 0 : (stage == .impact ? 1 : 0.5))

                // Handprint that stays behind.
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 170))
                    .foregroundStyle(Color.palsPink.opacity(0.45))
                    .rotationEffect(.degrees(-12))
                    .scaleEffect(stage == .incoming ? 0.6 : 1)
                    .opacity(stage == .incoming ? 0 : 1)

                Text("🖐️")
                    .font(.system(size: 230))
                    .rotationEffect(.degrees(arrived ? (stage == .aftermath ? -45 : -12) : 30))
                    .offset(x: stage == .aftermath ? -width * 1.3 : (arrived ? 0 : width * 1.3),
                            y: stage == .aftermath ? 80 : -20)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4).delay(0.05)) { arrived = true }
        }
    }
}

// MARK: - Egg

private struct EggAnimation: View {
    let stage: PrankOverlayView.Stage
    @State private var falling = false
    @State private var dripping = false

    var body: some View {
        GeometryReader { proxy in
            let midX = proxy.size.width / 2
            let impactY = proxy.size.height * 0.2

            ZStack {
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

import SwiftUI

/// Today's activity: a countdown if it has a timer, otherwise just "Mark as done".
struct ActivitySessionView: View {
    let activity: CircleActivity
    let streak: Int
    @Binding var proof: UIImage?
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var isRunning = false
    @State private var isFinished = false
    @State private var showingCamera = false

    init(activity: CircleActivity, streak: Int, proof: Binding<UIImage?>, onComplete: @escaping () -> Void) {
        self.activity = activity
        self.streak = streak
        _proof = proof
        self.onComplete = onComplete
        _remaining = State(initialValue: (activity.minutes ?? 0) * 60)
    }

    private var duration: Int { (activity.minutes ?? 0) * 60 }
    private var hasTimer: Bool { activity.minutes != nil }

    private var progress: Double {
        duration == 0 ? 1 : 1 - Double(remaining) / Double(duration)
    }

    private var streakLine: String {
        "Your streak is now \(streak == 1 ? "1 day" : "\(streak) days") 🔥"
    }

    /// "Walk for 5 minutes" → ["Walk for"] + "5 minutes."
    private var headline: (lines: [String], highlight: String) {
        let words = activity.title.split(separator: " ").map(String.init)
        guard words.count > 2 else { return ([], activity.title + ".") }
        let split = words.count / 2
        return ([words[..<split].joined(separator: " ")], words[split...].joined(separator: " ") + ".")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.palsOffWhite.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                if isFinished {
                    HighlightHeadline(lines: ["Nailed", "it,"], highlight: "pal!", size: 56)
                        .padding(.top, 72)
                    // `streak` is live from the model, so it already includes today.
                    Text(proof == nil
                         ? "\(streakLine)\nSnap a proof so your circle believes you."
                         : "\(streakLine)\nProof posted. Your circle can see it.")
                        .font(.palsBody(17))
                        .foregroundStyle(Color.palsInk.opacity(0.7))
                        .padding(.top, 16)
                } else {
                    // Without a timer the big emoji badge below already shows it.
                    if hasTimer {
                        Text(activity.emoji)
                            .font(.system(size: 44))
                            .padding(.top, 72)
                    }
                    HighlightHeadline(lines: headline.lines, highlight: headline.highlight, size: 48)
                        .padding(.top, hasTimer ? 4 : 72)
                }

                Spacer(minLength: 12)

                Group {
                    if isFinished, let proof {
                        ProofPolaroid(image: proof)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else if hasTimer {
                        timer
                    } else {
                        badge
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.palsInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(.leading, 20)
            .padding(.top, 16)
            .accessibilityLabel("Close")
        }
        .task(id: isRunning) {
            guard isRunning else { return }
            while isRunning && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, isRunning else { return }
                remaining -= 1
            }
            if remaining == 0 { finish() }
        }
        .sensoryFeedback(.success, trigger: isFinished)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                let small = image.preparingThumbnail(of: image.size.fitting(maxSide: 1200)) ?? image
                withAnimation(Motion.celebrate) { proof = small }
            }
            .ignoresSafeArea()
        }
    }

    /// Shown instead of the stopwatch for activities without a timer.
    private var badge: some View {
        Text(isFinished ? "✅" : activity.emoji)
            .font(.system(size: 110))
            .frame(width: 230, height: 230)
            .background(.white, in: Circle())
            .overlay(Circle().strokeBorder(Color.palsInk.opacity(0.08), lineWidth: 1))
            .contentTransition(.opacity)
            .accessibilityHidden(true)
    }

    private var timer: some View {
        ZStack {
            Image("OnboardingStopwatch")
                .resizable()
                .scaledToFit()
                .frame(width: 300)
                .opacity(isFinished ? 0.35 : 1)
                .accessibilityHidden(true)

            Text(isFinished ? "Done!" : timeString)
                .font(.palsDisplay(isFinished ? 54 : 64))
                .monospacedDigit()
                .foregroundStyle(Color.palsInk)
                .padding(.horizontal, 18)
                .padding(.vertical, 2)
                .background(Color.palsOffWhite.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: remaining)
        }
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(Color.palsInk.opacity(0.1))
                .frame(width: 240, height: 10)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.palsBlue)
                        .frame(width: 240 * (isFinished ? 1 : progress))
                        .animation(.linear(duration: 1), value: progress)
                }
                .offset(y: 28)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var buttons: some View {
        if isFinished {
            VStack(spacing: 14) {
                if proof == nil {
                    primaryButton("Snap proof", systemImage: "camera.fill") { showingCamera = true }
                    secondaryButton("Skip, back to my orbit") { dismiss() }
                } else {
                    primaryButton("Back to my orbit", systemImage: "arrow.right") { dismiss() }
                    secondaryButton("Retake photo") { showingCamera = true }
                }
            }
        } else if !hasTimer {
            VStack(spacing: 14) {
                primaryButton("Mark as done", systemImage: "checkmark") { finish() }
                secondaryButton("Not yet") { dismiss() }
            }
        } else {
            VStack(spacing: 14) {
                primaryButton(
                    isRunning ? "Pause" : (remaining == duration ? "Start" : "Resume"),
                    systemImage: isRunning ? "pause.fill" : "play.fill"
                ) {
                    isRunning.toggle()
                }

                Button("I'm done already") { finish() }
                    .font(.pals(17))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Image(systemName: systemImage)
                    .fontWeight(.heavy)
            }
            .font(.pals(23, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.pals(17))
            .foregroundStyle(.gray)
            .frame(maxWidth: .infinity, minHeight: 32)
    }

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private func finish() {
        isRunning = false
        withAnimation(Motion.celebrate) { isFinished = true }
        onComplete()
    }
}

/// The proof photo shown as a tilted polaroid with a lime "PROOF" sticker.
struct ProofPolaroid: View {
    let image: UIImage
    var width: CGFloat = 250

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: width - 24, height: width - 24)
                .clipped()
            Text("Today ✓")
                .font(.pals(width * 0.08))
                .foregroundStyle(Color.palsInk)
                .frame(height: width * 0.18)
        }
        .padding([.horizontal, .top], 12)
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .overlay(alignment: .topTrailing) {
            Text("PROOF")
                .font(.pals(width * 0.075))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.palsPink)
                .rotationEffect(.degrees(12))
                .offset(x: 14, y: -10)
        }
        .rotationEffect(.degrees(-4))
        .accessibilityElement()
        .accessibilityLabel("Your proof photo for today")
    }
}

private extension CGSize {
    func fitting(maxSide: CGFloat) -> CGSize {
        let ratio = min(1, maxSide / Swift.max(width, height))
        return CGSize(width: width * ratio, height: height * ratio)
    }
}

#Preview {
    ActivitySessionView(activity: CircleActivity.suggestions[0], streak: 12, proof: .constant(nil), onComplete: {})
}

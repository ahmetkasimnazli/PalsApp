import SwiftUI

/// Today's activity: a countdown if it has a timer, otherwise just "Mark as done".
/// Finishing leads straight into the proof: a back photo plus a selfie. Posting it
/// unlocks your pals' proofs for the day.
struct ActivitySessionView: View {
    let model: HomeModel
    let activity: CircleActivity

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int
    @State private var isRunning = false
    @State private var isFinished: Bool
    @State private var showingCamera = false
    @State private var viewing: DualProof?
    private let circleID: PalsCircle.ID

    init(model: HomeModel, activity: CircleActivity) {
        self.model = model
        self.activity = activity
        circleID = model.selectedCircleID
        _remaining = State(initialValue: (activity.minutes ?? 0) * 60)
        // Done already but no proof yet: open right at the proof step.
        _isFinished = State(initialValue: model.isDone(in: model.selectedCircle))
    }

    private var circle: PalsCircle? { model.circle(id: circleID) }
    private var proof: DualProof? { circle.flatMap(model.myProof(in:)) }
    private var palsProofs: [DualProof] { circle.map(model.proofs(in:))?.filter { !$0.isYours } ?? [] }
    private var streak: Int { model.streakDays }

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
                         ? "\(streakLine)\nNow share your moment: a photo and a selfie. Your pals' moments unlock when you do."
                         : "\(streakLine)\nMoment shared. Here's what your pals did.")
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
                        postedProofs(proof)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else if isFinished {
                        lockedPreview
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
            DualCameraView(activity: activity, you: UserDefaults.standard.string(forKey: "profileName") ?? "You") { proof in
                withAnimation(Motion.celebrate) { model.postProof(proof, in: circleID) }
            }
        }
        .fullScreenCover(item: $viewing) { proof in
            ProofViewer(proofs: circle.map(model.proofs(in:)) ?? [], startAt: proof.id)
        }
    }

    /// Your proof, and your pals' proofs now that they're unlocked.
    private func postedProofs(_ proof: DualProof) -> some View {
        VStack(spacing: 18) {
            Button { viewing = proof } label: {
                DualProofView(proof: proof, cornerRadius: 22, interactive: false)
                    .frame(width: palsProofs.isEmpty ? 240 : 190)
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    .rotationEffect(.degrees(-3))
            }
            .buttonStyle(PressableStyle())

            if !palsProofs.isEmpty {
                HStack(spacing: -14) {
                    ForEach(Array(palsProofs.prefix(4).enumerated()), id: \.element.id) { index, pal in
                        Button { viewing = pal } label: {
                            DualProofView(proof: pal, cornerRadius: 12, insetShare: 0.34, interactive: false)
                                .frame(width: 74)
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.palsOffWhite, lineWidth: 3))
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -5 : 5))
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(pal.author)'s moment")
                    }
                }
                Text(palsProofs.count == 1 ? "1 pal's moment unlocked" : "\(palsProofs.count) pals' moments unlocked")
                    .font(.pals(15))
                    .foregroundStyle(Color.palsInk.opacity(0.6))
            }
        }
    }

    /// Before you post: your pals' proofs, blurred. Nobody posted yet → the done badge.
    @ViewBuilder
    private var lockedPreview: some View {
        if palsProofs.isEmpty {
            badge
        } else {
            VStack(spacing: 14) {
                HStack(spacing: -18) {
                    ForEach(Array(palsProofs.prefix(3).enumerated()), id: \.element.id) { index, pal in
                        DualProofView(proof: pal, cornerRadius: 16, interactive: false)
                            .frame(width: 110)
                            .blur(radius: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .rotationEffect(.degrees(Double(index - 1) * 6))
                    }
                }
                .overlay { Text("🔒").font(.system(size: 44)) }
                .accessibilityHidden(true)
                Text(palsProofs.count == 1 ? "1 pal already posted" : "\(palsProofs.count) pals already posted")
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk.opacity(0.6))
            }
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
                    primaryButton("Snap my moment", systemImage: "camera.fill") { showingCamera = true }
                    secondaryButton("Later") { dismiss() }
                } else {
                    primaryButton("Back to my orbit", systemImage: "arrow.right") { dismiss() }
                    secondaryButton("Retake moment") { showingCamera = true }
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
        model.completeTodayActivity(in: circleID)
        // Straight on to the proof, while the moment's still there.
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            showingCamera = true
        }
    }
}

#Preview {
    ActivitySessionView(model: HomeModel(), activity: CircleActivity.suggestions[0])
}

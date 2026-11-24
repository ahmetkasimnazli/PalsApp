import SwiftUI

/// App shell after onboarding: Orbit (home), Circles, Progress, Profile.
struct MainTabView: View {
    let name: String
    var onRestartOnboarding: () -> Void

    private enum AppTab { case orbit, circles, progress, profile }

    @State private var model = HomeModel()
    @State private var photo = ProfilePhotoStore.load()
    @State private var tab: AppTab = .orbit
    /// Today's card (or another way to start the activity) is on screen on the Orbit tab.
    @State private var startOnScreen = false
    @State private var circlesPath: [PalsCircle.ID] = []
    @State private var playingPrank: IncomingPrank?
    @State private var shakes: CGFloat = 0
    /// A quick zoom "punch" of the whole app on impact.
    @State private var punched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                Tab("Orbit", systemImage: "circle.circle", value: AppTab.orbit) {
                    HomeView(model: model, name: name, photo: photo, onViewCircle: { id in
                        circlesPath = [id]
                        tab = .circles
                    }, startOnScreen: $startOnScreen)
                }
                Tab("Circles", systemImage: "person.3", value: AppTab.circles) {
                    CirclesView(model: model, path: $circlesPath) { tab = .orbit }
                }
                Tab("Progress", systemImage: "chart.bar", value: AppTab.progress) {
                    ProgressDeckView(model: model)
                }
                Tab("Profile", systemImage: "person", value: AppTab.profile) {
                    ProfileView(model: model, photo: $photo,
                                onOpenCircle: { id in
                                    circlesPath = [id]
                                    tab = .circles
                                },
                                onRestartOnboarding: onRestartOnboarding)
                }
            }
            // Today's activity is one tap away above the tab bar, except while the Orbit page
            // already shows something that does the same thing.
            .tabViewBottomAccessory(isEnabled: !(tab == .orbit && startOnScreen)) {
                ActivityAccessory(activity: model.selectedCircle.today, done: model.completedToday,
                                  revealed: model.isRevealed(model.selectedCircle)) {
                    // The draw plays on the Orbit tab.
                    if !model.isRevealed(model.selectedCircle) { tab = .orbit }
                    model.startActivity()
                }
            }
            .sheet(item: $model.activeActivity) { activity in
                ActivitySessionView(model: model, activity: activity)
                .preferredColorScheme(.light)
            }
            .tint(tab == .orbit ? .white : .palsBlue)
            // Orbit sits on brand blue: light status bar, dark tab-bar glass there.
            .preferredColorScheme(tab == .orbit ? .dark : .light)
            .modifier(ShakeEffect(animatableData: shakes))
            .scaleEffect(punched ? 1.06 : 1)
            // Interactive glass buttons underneath could otherwise catch taps meant for the prank card.
            .allowsHitTesting(playingPrank == nil)

            if let prank = playingPrank {
                PrankOverlayView(
                    prank: prank,
                    onImpact: {
                        withAnimation(Motion.shake) { shakes += 1 }
                        guard !reduceMotion else { return }
                        withAnimation(Motion.punchIn) { punched = true }
                        Task {
                            try? await Task.sleep(for: .milliseconds(120))
                            withAnimation(Motion.punchOut) { punched = false }
                        }
                    },
                    onStartActivity: {
                        finishPrank()
                        tab = .orbit
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            model.startActivity()
                        }
                    },
                    onDismiss: finishPrank
                )
                .id(prank.id)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .task {
            // Compile the impact shader up front; compiling it on first use stalls the prank.
            try? await ShaderLibrary.impactWave(.float2(0, 0), .float(0), .float(0)).compile(as: .layerEffect)
        }
        .task {
            // Real circles first; the demo launch prank only plays when there are none.
            await model.refresh()
            model.playDemoLaunchPrank()
            // Pranks play when you open the app — give the home screen a moment first.
            try? await Task.sleep(for: .milliseconds(700))
            playPendingPrank()
        }
        .task(id: scenePhase) {
            // Keep real circles fresh while the app is open: pals' moments, pranks, who's done.
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await model.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .alert("iCloud", isPresented: Binding(get: { model.cloudError != nil },
                                              set: { if !$0 { model.cloudError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.cloudError ?? "")
        }
        .onChange(of: model.incomingPrank) { _, _ in
            playPendingPrank()
        }
    }

    private func playPendingPrank() {
        guard playingPrank == nil, let prank = model.incomingPrank else { return }
        withAnimation(Motion.appear) { playingPrank = prank }
    }

    private func finishPrank() {
        model.incomingPrank = nil
        withAnimation(Motion.disappear) { playingPrank = nil }
    }
}

/// Compact "today's activity" bar shown in the tab bar's accessory slot.
private struct ActivityAccessory: View {
    let activity: CircleActivity
    let done: Bool
    let revealed: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(hex: 0x22C55E))
                } else {
                    Text(revealed ? activity.emoji : "🃏")
                        .font(.system(size: 26))
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(done ? "Done for today" : (revealed ? "Today's activity" : "Today's card"))
                        .font(.palsBody(12))
                        .foregroundStyle(.secondary)
                    Text(revealed ? activity.title : "Not drawn yet")
                        .font(.pals(16))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if done {
                    Text("✓")
                        .font(.pals(16, weight: .bold))
                        .foregroundStyle(Color(hex: 0x22C55E))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: revealed ? "play.fill" : "rectangle.stack.fill")
                        Text(revealed ? "Start" : "Draw")
                    }
                    .font(.pals(15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.palsBlue, in: Capsule())
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Faint white frost over the system glass capsule (no color tint).
            .background(.white.opacity(0.30), in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(done ? "Done for today: \(activity.title)" : "Start today's activity: \(activity.title)")
    }
}

private struct ComingSoonView: View {
    let lines: [String]
    let highlight: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HighlightHeadline(lines: lines, highlight: highlight, size: 52)
            Text("Coming soon.")
                .font(.palsBody(17))
                .foregroundStyle(Color.palsInk.opacity(0.6))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.palsOffWhite.ignoresSafeArea())
    }
}

#Preview {
    MainTabView(name: "Ahmet", onRestartOnboarding: {})
}

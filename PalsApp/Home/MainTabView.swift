import SwiftUI

/// App shell after onboarding: Orbit (home), Circles, Progress, Profile.
struct MainTabView: View {
    let name: String
    let username: String
    var onRestartOnboarding: () -> Void

    private enum AppTab { case orbit, circles, progress, profile }

    @State private var model = HomeModel()
    @State private var photo = ProfilePhotoStore.load()
    @State private var tab: AppTab = .orbit
    @State private var circlesPath: [PalsCircle.ID] = []
    @State private var playingPrank: IncomingPrank?
    @State private var shakes: CGFloat = 0

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                Tab("Orbit", systemImage: "circle.circle", value: AppTab.orbit) {
                    HomeView(model: model, name: name, photo: photo) { id in
                        circlesPath = [id]
                        tab = .circles
                    }
                }
                Tab("Circles", systemImage: "person.3", value: AppTab.circles) {
                    CirclesView(model: model, path: $circlesPath) { tab = .orbit }
                }
                Tab("Progress", systemImage: "chart.bar", value: AppTab.progress) {
                    ComingSoonView(lines: ["Your"], highlight: "progress.")
                }
                Tab("Profile", systemImage: "person", value: AppTab.profile) {
                    ProfileTabView(name: name, username: username, photo: photo,
                                   onResetToday: { withAnimation { model.resetToday() } },
                                   onRestartOnboarding: onRestartOnboarding)
                }
            }
            .tint(tab == .orbit ? .white : .palsBlue)
            // Orbit sits on brand blue: light status bar, dark tab-bar glass there.
            .preferredColorScheme(tab == .orbit ? .dark : .light)
            .modifier(ShakeEffect(animatableData: shakes))
            // Interactive glass buttons underneath could otherwise catch taps meant for the prank card.
            .allowsHitTesting(playingPrank == nil)

            if let prank = playingPrank {
                PrankOverlayView(
                    prank: prank,
                    onImpact: {
                        withAnimation(.linear(duration: 0.45)) { shakes += 1 }
                    },
                    onStartActivity: {
                        finishPrank()
                        tab = .orbit
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            model.showingActivity = true
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
            // Pranks play when you open the app — give the home screen a moment first.
            try? await Task.sleep(for: .milliseconds(700))
            playPendingPrank()
        }
        .onChange(of: model.incomingPrank) { _, _ in
            playPendingPrank()
        }
    }

    private func playPendingPrank() {
        guard playingPrank == nil, let prank = model.incomingPrank else { return }
        withAnimation(.easeIn(duration: 0.2)) { playingPrank = prank }
    }

    private func finishPrank() {
        model.incomingPrank = nil
        withAnimation(.easeOut(duration: 0.3)) { playingPrank = nil }
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

private struct ProfileTabView: View {
    let name: String
    let username: String
    let photo: UIImage?
    var onResetToday: () -> Void
    var onRestartOnboarding: () -> Void

    @State private var didReset = false

    var body: some View {
        VStack(spacing: 16) {
            PalsAvatar(name: name.isEmpty ? "You" : name, photo: photo, size: 120)
            Text(name.isEmpty ? "Pal" : name)
                .font(.palsDisplay(34))
                .foregroundStyle(Color.palsInk)
            if !username.isEmpty {
                Text("@\(username)")
                    .font(.palsBody(17))
                    .foregroundStyle(Color.palsInk.opacity(0.6))
            }
            Button(didReset ? "Today reset ✓" : "Reset today (demo)") {
                onResetToday()
                didReset = true
            }
            .font(.pals(17))
            .foregroundStyle(Color.palsBlue)
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.top, 24)

            Button("Restart onboarding", action: onRestartOnboarding)
                .font(.pals(17))
                .foregroundStyle(Color.palsBlue)
                .buttonStyle(.glass)
                .controlSize(.large)

            Text("Demo: tap the bell on the Orbit tab to get pranked by a pal.")
                .font(.palsBody(14))
                .foregroundStyle(Color.palsInk.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)
        }
        .onDisappear { didReset = false }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.palsOffWhite.ignoresSafeArea())
    }
}

#Preview {
    MainTabView(name: "Ahmet", username: "ahmetk", onRestartOnboarding: {})
}

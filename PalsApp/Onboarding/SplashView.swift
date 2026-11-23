import SwiftUI

/// Picks up exactly where LaunchScreen.storyboard leaves off (same color, same logo size and
/// position), so the system launch screen and this view look like one continuous splash.
/// It only adds a small bounce before the app moves on.
struct SplashView: View {
    @State private var bounce = false

    var body: some View {
        ZStack {
            Color.palsIndigo
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 330)
                .scaleEffect(bounce ? 1.08 : 1)
                .accessibilityLabel("Pals")
        }
        // Centered on the whole screen, like the storyboard, not inside the safe area.
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.25, bounce: 0.5)) { bounce = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) { bounce = false }
        }
    }
}

#Preview {
    SplashView()
}

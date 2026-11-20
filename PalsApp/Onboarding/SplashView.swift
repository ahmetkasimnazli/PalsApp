import SwiftUI

struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.palsIndigo.ignoresSafeArea()
            Image("SplashLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 330)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
                .accessibilityLabel("Pals")
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    SplashView()
}

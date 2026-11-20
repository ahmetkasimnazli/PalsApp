import SwiftUI

/// Last onboarding screen before profile setup. No account needed: identity comes from
/// the device's iCloud account later, so there's just one button to get going.
struct WelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.palsIndigo.ignoresSafeArea()

            VStack(spacing: 0) {
                Image("PalsLogo3D")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140)
                    .padding(.top, 12)
                    .accessibilityLabel("Pals")

                Spacer(minLength: 16)

                // Centered between the logo and the button.
                Image("WelcomeGroup")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, -20)
                    .accessibilityHidden(true)

                Spacer(minLength: 24)

                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("Get started")
                        Image(systemName: "arrow.right")
                            .fontWeight(.heavy)
                    }
                    .font(.pals(23, weight: .bold))
                    .foregroundStyle(Color.palsIndigo)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.white).interactive(), in: .capsule)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}

import SwiftUI

/// Last onboarding screen before profile setup. There's no account to make: identity comes
/// from the device's iCloud account, so this screen just sells the idea and gets you going.
struct WelcomeView: View {
    var onContinue: () -> Void

    private struct Point: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    private let points = [
        Point(icon: "figure.walk", text: "Pick one small thing to do every day"),
        Point(icon: "person.3.fill", text: "Do it with your pals, keep the streak"),
        Point(icon: "hand.raised.fill", text: "Skip it, and they get to prank you"),
    ]

    var body: some View {
        ZStack {
            Color.palsIndigo.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Image("SplashLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.palsOffWhite)
                    .frame(height: 56)
                    .padding(.leading, -16)
                    .accessibilityLabel("Pals")

                HighlightHeadline(lines: ["Show up"], highlight: "Or get pranked", size: 50, color: .palsOffWhite)
                    .padding(.top, 14)

                Image("WelcomeGroup")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, -16)
                    .padding(.vertical, 4)
                    .layoutPriority(-1)
                    .accessibilityHidden(true)

                GlassEffectContainer(spacing: 8) {
                    VStack(spacing: 8) {
                        ForEach(points) { point in
                            HStack(spacing: 14) {
                                Image(systemName: point.icon)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.palsIndigo)
                                    .frame(width: 36, height: 36)
                                    .background(Color.palsOffWhite, in: Circle())
                                Text(point.text)
                                    .font(.pals(16))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        }
                    }
                }

                Spacer(minLength: 16)

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
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.white).interactive(), in: .capsule)

                Label("No sign-up. Pals uses your iCloud account.", systemImage: "icloud.fill")
                    .font(.palsBody(14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

/// The app's press feedback for custom buttons: a subtle scale-down the moment a finger lands,
/// released quickly. Responding on touch-down is what makes a tap feel heard.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(configuration.isPressed ? Motion.pressDown : Motion.pressUp, value: configuration.isPressed)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}

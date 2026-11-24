import SwiftUI

/// The only "sign-up" step: a name and an optional photo. That's all your pals see of you;
/// your identity itself comes from iCloud, so there's no username or password.
struct ProfileSetupView: View {
    var onFinish: (_ name: String, _ photo: UIImage?) -> Void
    var onSkip: () -> Void

    @State private var name = ""
    @State private var photo: UIImage?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canContinue: Bool { !trimmedName.isEmpty }

    var body: some View {
        ZStack {
            Color.palsIndigo
                .ignoresSafeArea()
                .onTapGesture { nameFocused = false }

            VStack(alignment: .leading, spacing: 0) {
                HighlightHeadline(lines: ["What do your"], highlight: "pals call you?", size: 46, color: .palsOffWhite)
                    .padding(.top, 48)

                Spacer(minLength: 12)

                VStack(spacing: 14) {
                    // Smaller while typing so the field stays above the keyboard.
                    ProfilePhotoPicker(photo: $photo, name: name, size: nameFocused ? 112 : 176)
                    Text(photo == nil ? "Add a photo so your pals spot you on their orbit." : "Looking good.")
                        .font(.palsBody(15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .opacity(nameFocused ? 0 : 1)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 12)

                TextField("", text: $name, prompt: Text("Your name").foregroundStyle(.white.opacity(0.5)))
                    .font(.pals(20))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($nameFocused)
                    .textContentType(.givenName)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding(.horizontal, 22)
                    .frame(height: 58)
                    .glassEffect(.regular, in: .capsule)
                    // The whole capsule focuses the field, not just the text line.
                    .contentShape(Capsule())
                    .onTapGesture { nameFocused = true }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        Text("Let’s go!")
                        Image(systemName: "arrow.right")
                            .fontWeight(.heavy)
                    }
                    .font(.pals(23, weight: .bold))
                    .foregroundStyle(Color.palsIndigo)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.white).interactive(canContinue), in: .capsule)
                .opacity(canContinue ? 1 : 0.5)
                .disabled(!canContinue)
                .padding(.top, 14)

                Button("Skip for now", action: onSkip)
                    .font(.pals(17))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }
            .padding(.horizontal, 20)
            .animation(Motion.expand, value: nameFocused)
            .animation(Motion.update, value: canContinue)
        }
    }

    private func submit() {
        guard canContinue else { return }
        onFinish(trimmedName, photo)
    }
}

#Preview {
    ProfileSetupView(onFinish: { _, _ in }, onSkip: {})
}

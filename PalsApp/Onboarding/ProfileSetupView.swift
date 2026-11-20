import SwiftUI

struct ProfileSetupView: View {
    var onFinish: (_ name: String, _ username: String, _ photo: UIImage?) -> Void
    var onSkip: () -> Void

    @State private var name = ""
    @State private var username = ""
    @State private var photo: UIImage?
    @FocusState private var focused: Field?

    private enum Field { case name, username }

    /// Lowercased, without "@" or spaces — only letters, digits, "_" and ".".
    private var cleanedUsername: String {
        username.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
    }

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !cleanedUsername.isEmpty
    }

    var body: some View {
        ZStack {
            Color.palsOffWhite
                .ignoresSafeArea()
                .onTapGesture { focused = nil }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    HighlightHeadline(lines: ["Set Up", "Your"], highlight: "Profile.", size: 48)
                    BurstMarks()
                        .padding(.top, 36)
                    Spacer(minLength: 0)
                }
                .padding(.top, 64)

                // Hidden while typing — there isn't enough room above the keyboard.
                if focused == nil {
                    ProfilePhotoPicker(photo: $photo)
                        .frame(maxWidth: .infinity, maxHeight: 290)
                        .padding(.horizontal, -12)
                        .padding(.top, -16)
                        .layoutPriority(-1)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Name")
                    PalsTextField(placeholder: "Your name", text: $name)
                        .focused($focused, equals: .name)
                        .textContentType(.name)
                        .submitLabel(.next)
                        .onSubmit { focused = .username }

                    fieldLabel("Username")
                        .padding(.top, 12)
                    PalsTextField(placeholder: "@ yourusername", text: $username)
                        .focused($focused, equals: .username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(submit)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        Text("Let’s Go!")
                        Image(systemName: "arrow.right")
                            .fontWeight(.heavy)
                    }
                    .font(.pals(23, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.palsBlue.opacity(canContinue ? 1 : 0.45)).interactive(canContinue), in: .capsule)
                .disabled(!canContinue)
                .padding(.top, 44)

                Button("Skip for now", action: onSkip)
                    .font(.pals(17))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.25), value: focused)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.pals(17))
            .foregroundStyle(Color.palsInk)
            .padding(.leading, 6)
    }

    private func submit() {
        guard canContinue else { return }
        onFinish(name.trimmingCharacters(in: .whitespaces), cleanedUsername, photo)
    }
}

private struct PalsTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.palsBody(17))
            .padding(.horizontal, 20)
            .frame(height: 46)
            .background(.white, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.gray, lineWidth: 1))
    }
}

#Preview {
    ProfileSetupView(onFinish: { _, _, _ in }, onSkip: {})
}

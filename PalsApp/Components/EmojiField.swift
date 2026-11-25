import SwiftUI
import UIKit

/// A big round well holding one emoji. Tapping it opens the emoji keyboard; picking an emoji
/// replaces the current one and closes the keyboard. Anything that isn't an emoji is ignored,
/// so letters, numbers or a deleted emoji never end up here.
struct EmojiField: View {
    @Binding var emoji: String
    var size: CGFloat = 76

    @State private var editing = false

    var body: some View {
        EmojiTextField(emoji: $emoji, editing: $editing, fontSize: size * 0.52)
            .frame(width: size, height: size)
            .background(.white, in: Circle())
            // A dashed ring says "you can change this"; it turns solid blue while picking.
            .overlay(
                Circle().strokeBorder(editing ? Color.palsBlue : Color.palsInk.opacity(0.25),
                                      style: StrokeStyle(lineWidth: editing ? 3 : 1.5, dash: editing ? [] : [5, 4]))
            )
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.palsBlue, in: Circle())
                    .overlay(Circle().strokeBorder(Color.palsOffWhite, lineWidth: 2.5))
                    .offset(x: 2, y: 2)
                    .allowsHitTesting(false)
            }
            .scaleEffect(editing ? 1.06 : 1)
            .animation(Motion.select, value: editing)
            .accessibilityElement()
            .accessibilityLabel("Emoji, \(emoji)")
            .accessibilityHint("Double tap to pick any emoji")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { editing.toggle() }
    }
}

extension Character {
    /// Drawn as an emoji: a pictograph, a flag, a sequence with a skin tone or ZWJ, or a
    /// keycap. Plain digits, letters and symbols like "#" don't count.
    var isEmoji: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation
            || (first.properties.isEmoji && unicodeScalars.count > 1)
    }
}

/// The UIKit field behind `EmojiField`: asks for the emoji keyboard and keeps exactly one emoji.
private struct EmojiTextField: UIViewRepresentable {
    @Binding var emoji: String
    @Binding var editing: Bool
    let fontSize: CGFloat

    func makeUIView(context: Context) -> EmojiKeyboardTextField {
        let field = EmojiKeyboardTextField()
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.font = .systemFont(ofSize: fontSize)
        field.tintColor = .clear // no caret
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .done
        field.text = emoji
        return field
    }

    func updateUIView(_ field: EmojiKeyboardTextField, context: Context) {
        if field.text != emoji { field.text = emoji }
        // Open or close the keyboard to match `editing` (e.g. from VoiceOver).
        DispatchQueue.main.async {
            if editing && !field.isFirstResponder { field.becomeFirstResponder() }
            if !editing && field.isFirstResponder { field.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        init(_ parent: EmojiTextField) { self.parent = parent }

        func textFieldDidBeginEditing(_ textField: UITextField) { parent.editing = true }
        func textFieldDidEndEditing(_ textField: UITextField) { parent.editing = false }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }

        /// Keeps only the last emoji typed or pasted; everything else (and deleting) is ignored.
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard let picked = string.last(where: \.isEmoji) else { return false }
            let value = String(picked)
            textField.text = value
            parent.emoji = value
            // One pick is all it takes.
            textField.resignFirstResponder()
            return false
        }
    }
}

/// A text field that opens on the emoji keyboard (falling back to the normal one if the
/// user has removed the emoji keyboard in Settings).
private final class EmojiKeyboardTextField: UITextField {
    // A non-nil identifier is needed for the system to honour `textInputMode`.
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }

    // Nothing to select, copy or edit inside a single emoji.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        action == #selector(paste(_:))
    }

    override func caretRect(for position: UITextPosition) -> CGRect { .zero }
}

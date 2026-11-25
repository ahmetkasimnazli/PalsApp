import SwiftUI
import UIKit

/// Turns one of your Memoji stickers into a profile photo. There's no Memoji API, but Memoji
/// stickers live on the emoji keyboard and arrive in a text view as adaptive image glyphs, so
/// the sheet opens that keyboard, catches the sticker you tap, and puts it on a colour you pick.
struct MemojiPickerSheet: View {
    var onPick: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var memoji: UIImage?
    @State private var background = MemojiPickerSheet.backgrounds[0]
    @State private var keyboardUp = true
    /// Something other than a sticker was typed.
    @State private var wrongInput = false

    static let backgrounds: [Color] = [.palsPink, .palsBlue, Color(hex: 0x22A06B), Color(hex: 0xF5A524),
                                       Color(hex: 0x7B5CFF), Color(hex: 0x14B8A6)]

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                HighlightHeadline(lines: ["Your"], highlight: "Memoji", size: 44)
                Spacer()
                CloseButton { dismiss() }
            }

            preview
                .padding(.top, 4)

            if memoji != nil {
                colors
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Text(hint)
                .font(.palsBody(15))
                .foregroundStyle(wrongInput ? Color.palsPink : Color.palsInk.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)

            if memoji != nil {
                Button {
                    if let memoji { onPick(Self.avatar(memoji, on: background)) }
                    dismiss()
                } label: {
                    Text("Use this Memoji")
                        .font(.pals(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
                .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Off screen in practice: it only exists to bring up the keyboard and catch stickers.
            StickerCatcher(isActive: $keyboardUp) { result in
                withAnimation(Motion.select) {
                    switch result {
                    case .sticker(let image):
                        memoji = image
                        wrongInput = false
                        keyboardUp = false
                    case .notASticker:
                        wrongInput = true
                    }
                }
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .accessibilityHidden(true)
        }
        .padding(24)
        .presentationBackground(Color.palsOffWhite)
        .presentationDetents([.large])
        .animation(Motion.select, value: memoji == nil)
        .sensoryFeedback(.success, trigger: memoji)
    }

    private var hint: String {
        if wrongInput { return "That's not a Memoji. Swipe to the stickers on the emoji keyboard and tap your Memoji." }
        if memoji != nil { return "Pick a colour behind it, or tap your Memoji to choose another." }
        return "On the emoji keyboard, swipe right to the stickers and tap your Memoji."
    }

    /// Your Memoji on the chosen colour, as pals will see it. Tap to bring the keyboard back.
    private var preview: some View {
        Button { keyboardUp = true } label: {
            ZStack {
                if let memoji {
                    background
                    Image(uiImage: memoji)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                } else {
                    Color.white
                    Image(systemName: "face.smiling")
                        .font(.system(size: 54, weight: .regular))
                        .foregroundStyle(Color.palsInk.opacity(0.25))
                }
            }
            .frame(width: 176, height: 176)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.palsInk.opacity(memoji == nil ? 0.2 : 0),
                                           style: StrokeStyle(lineWidth: 2, dash: [7, 6])))
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
        .accessibilityLabel(memoji == nil ? "Pick your Memoji" : "Your Memoji. Double tap to pick another.")
    }

    private var colors: some View {
        HStack(spacing: 12) {
            ForEach(Self.backgrounds, id: \.self) { color in
                Button {
                    withAnimation(Motion.select) { background = color }
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3).opacity(color == background ? 1 : 0))
                        .overlay(Circle().strokeBorder(color, lineWidth: 2).padding(-4).opacity(color == background ? 1 : 0))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Background colour")
                .accessibilityAddTraits(color == background ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: background)
    }

    /// A square photo: the colour, with the Memoji centred and a little room around it.
    static func avatar(_ memoji: UIImage, on color: Color, side: CGFloat = 600) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor(color).setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let inset = side * 0.08
            let box = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
            let ratio = min(box.width / memoji.size.width, box.height / memoji.size.height)
            let drawn = CGSize(width: memoji.size.width * ratio, height: memoji.size.height * ratio)
            memoji.draw(in: CGRect(x: box.midX - drawn.width / 2, y: box.midY - drawn.height / 2,
                                   width: drawn.width, height: drawn.height))
        }
    }
}

// MARK: - Catching a sticker

/// A hidden text view that accepts stickers (adaptive image glyphs) and opens on the emoji
/// keyboard. Reports the sticker's image, or that something else was typed.
private struct StickerCatcher: UIViewRepresentable {
    enum Result { case sticker(UIImage), notASticker }

    @Binding var isActive: Bool
    var onInput: (Result) -> Void

    func makeUIView(context: Context) -> EmojiKeyboardTextView {
        let view = EmojiKeyboardTextView()
        view.supportsAdaptiveImageGlyph = true
        view.delegate = context.coordinator
        view.autocorrectionType = .no
        view.backgroundColor = .clear
        view.tintColor = .clear
        return view
    }

    func updateUIView(_ view: EmojiKeyboardTextView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            if isActive && !view.isFirstResponder { view.becomeFirstResponder() }
            if !isActive && view.isFirstResponder { view.resignFirstResponder() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: StickerCatcher
        init(_ parent: StickerCatcher) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.isActive = true }
        func textViewDidEndEditing(_ textView: UITextView) { parent.isActive = false }

        func textViewDidChange(_ textView: UITextView) {
            let text = textView.attributedText ?? NSAttributedString()
            guard text.length > 0 else { return }
            var sticker: UIImage?
            text.enumerateAttribute(.adaptiveImageGlyph, in: NSRange(location: 0, length: text.length)) { value, _, stop in
                if let glyph = value as? NSAdaptiveImageGlyph, let image = UIImage(data: glyph.imageContent) {
                    sticker = image
                    stop.pointee = true
                }
            }
            // Start fresh each time: only ever one sticker (or nothing) in here.
            textView.attributedText = NSAttributedString()
            parent.onInput(sticker.map { .sticker($0) } ?? .notASticker)
        }
    }
}

/// A text view that comes up on the emoji keyboard, where the Memoji stickers are.
private final class EmojiKeyboardTextView: UITextView {
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}

#Preview {
    Text("Profile")
        .sheet(isPresented: .constant(true)) {
            MemojiPickerSheet { _ in }
        }
}

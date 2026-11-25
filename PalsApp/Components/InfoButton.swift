import SwiftUI

/// A small grey ⓘ next to a heading. Tap it for the line that explains the section, in a
/// popover, so the screen itself stays clean.
struct InfoButton: View {
    let text: String
    var size: CGFloat = 17
    /// Grey on light backgrounds; white on the brand colour.
    var onDark = false

    @State private var showing = false

    init(_ text: String, size: CGFloat = 17, onDark: Bool = false) {
        self.text = text
        self.size = size
        self.onDark = onDark
    }

    var body: some View {
        Button { showing = true } label: {
            Image(systemName: "info.circle")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(onDark ? Color.white.opacity(0.6) : Color.palsInk.opacity(0.35))
                // A comfortable target around a small glyph.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("More info")
        .accessibilityHint(text)
        .popover(isPresented: $showing, arrowEdge: .top) {
            Text(text)
                .font(.palsBody(15))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(16)
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.selection, trigger: showing)
    }
}

extension View {
    /// Puts an `InfoButton` right after a one-line heading, centred on it. For `HighlightHeadline`
    /// use its `info:` parameter, which puts the button after the last line.
    func info(_ text: String, size: CGFloat = 17, onDark: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 0) {
            self
            InfoButton(text, size: size, onDark: onDark)
                .padding(.leading, -8)
                .padding(.vertical, -12)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        HighlightHeadline(lines: ["Your"], highlight: "circles", size: 52,
                          info: "Every day each circle gets one activity from its pool.")
        Text("THE POOL").font(.pals(14)).tracking(1).foregroundStyle(.secondary)
            .info("Every day one card is drawn from this deck for everyone.", size: 14)
    }
    .padding()
    .background(Color.palsOffWhite)
}

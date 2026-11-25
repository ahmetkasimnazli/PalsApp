import SwiftUI

/// Big display headline, one line per entry,
/// e.g. "Get / things / done / **together**"
struct HighlightHeadline: View {
    let lines: [String]
    let highlight: String
    var size: CGFloat = 64
    var color: Color = .palsInk
    /// Explains the section behind a small info button, right after the last line.
    var info: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.2) {
            // Headlines never end in a period ("?" and "!" stay).
            ForEach(lines, id: \.self) { line in
                Text(Self.trimmed(line))
                    .accessibilityAddTraits(.isHeader)
            }
            HStack(alignment: .center, spacing: 0) {
                Text(Self.trimmed(highlight))
                    .accessibilityAddTraits(.isHeader)
                if let info {
                    InfoButton(info, size: Self.infoSize(for: size), onDark: color != .palsInk)
                        // Optically on the letters (the line box includes the descender room).
                        .offset(y: -size * 0.04)
                        .padding(.leading, -4)
                        .padding(.vertical, -10)
                }
            }
        }
        .font(.palsDisplay(size))
        .tracking(-size * 0.03)
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .contain)
    }

    /// Small next to the headline, but never tiny.
    private static func infoSize(for size: CGFloat) -> CGFloat {
        min(22, max(16, size * 0.38))
    }

    private static func trimmed(_ text: String) -> String {
        var text = text
        while text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

/// Three short "motion" strokes used as a decoration next to headlines.
struct BurstMarks: View {
    var color: Color = .palsInk

    var body: some View {
        ZStack {
            Capsule().frame(width: 7, height: 34)
                .rotationEffect(.degrees(15))
                .offset(x: -26, y: 8)
            Capsule().frame(width: 7, height: 40)
                .rotationEffect(.degrees(40))
                .offset(x: 0, y: -6)
            Capsule().frame(width: 7, height: 34)
                .rotationEffect(.degrees(70))
                .offset(x: 22, y: 20)
        }
        .foregroundStyle(color)
        .frame(width: 70, height: 60)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 40) {
        HighlightHeadline(lines: ["Get", "things", "done"], highlight: "together")
        HighlightHeadline(lines: ["Set Up", "Your"], highlight: "Profile", size: 48)
        BurstMarks()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.palsOffWhite)
}

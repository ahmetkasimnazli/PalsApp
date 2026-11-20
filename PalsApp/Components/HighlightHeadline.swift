import SwiftUI

/// Big italic headline whose last line sits on a tilted lime band,
/// e.g. "Get / things / done / **together.**"
struct HighlightHeadline: View {
    let lines: [String]
    let highlight: String
    var size: CGFloat = 64

    var body: some View {
        VStack(alignment: .leading, spacing: -size * 0.2) {
            ForEach(lines, id: \.self) { line in
                Text(line)
            }
            Text(highlight)
        }
        .font(.palsDisplay(size))
        .tracking(-size * 0.03)
        .foregroundStyle(Color.palsInk)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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
        HighlightHeadline(lines: ["Get", "things", "done"], highlight: "together.")
        HighlightHeadline(lines: ["Set Up", "Your"], highlight: "Profile.", size: 48)
        BurstMarks()
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Color.palsOffWhite)
}

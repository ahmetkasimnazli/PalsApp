import SwiftUI

/// Picks an activity's timer by scrolling a ruler under a big readout, like a camera's zoom
/// dial. Each minute clicks into place with a light tick; 0 at the far left means no timer.
/// Tap a labelled mark to jump straight to it.
struct TimerDial: View {
    /// `nil` = no timer.
    @Binding var minutes: Int?
    var range: ClosedRange<Int> = 0...60

    @State private var position: Int?
    @State private var width: CGFloat = 350

    private static let step: CGFloat = 14
    private var value: Int { position ?? minutes ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            readout

            ZStack {
                ruler
                // The needle in the middle, over the ticks but clear of the labels.
                Capsule()
                    .fill(Color.palsBlue)
                    .frame(width: 4, height: 40)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
            }
            .frame(height: 70)
            .mask(
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.18),
                                       .init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onAppear { position = minutes ?? 0 }
        .onChange(of: position) {
            guard let position else { return }
            let new = position == 0 ? nil : position
            if new != minutes { minutes = new }
        }
        // Set from outside (e.g. picking an idea): move the ruler there.
        .onChange(of: minutes) {
            let target = minutes ?? 0
            if position != target { withAnimation(Motion.select) { position = target } }
        }
        .sensoryFeedback(.selection, trigger: position)
        .accessibilityElement()
        .accessibilityLabel("Timer")
        .accessibilityValue(value == 0 ? "No timer" : "\(value) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: position = min(range.upperBound, value + 1)
            case .decrement: position = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private var readout: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if value == 0 {
                Text("No timer")
                    .font(.palsDisplay(40))
            } else {
                Text("\(value)")
                    .font(.palsDisplay(56))
                    .contentTransition(.numericText(value: Double(value)))
                Text("min")
                    .font(.pals(22, weight: .bold))
                    .foregroundStyle(Color.palsInk.opacity(0.5))
            }
        }
        .foregroundStyle(Color.palsInk)
        .frame(height: 64)
        .animation(Motion.select, value: value)
    }

    private var ruler: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(range), id: \.self) { minute in
                    tick(minute)
                        .frame(width: Self.step)
                        .id(minute)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $position, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        // Room on both sides so 0 and 60 can reach the needle.
        .safeAreaPadding(.horizontal, max(0, width / 2 - Self.step / 2))
    }

    private func tick(_ minute: Int) -> some View {
        let major = minute % 5 == 0
        let near = abs(minute - value)
        return VStack(spacing: 6) {
            Capsule()
                .fill(near == 0 ? Color.palsBlue : Color.palsInk.opacity(major ? 0.45 : 0.2))
                .frame(width: major ? 3 : 2, height: major ? 30 : 16)
                .frame(height: 30, alignment: .bottom)
            if major {
                Text(minute == 0 ? "Off" : "\(minute)")
                    .font(.pals(12, weight: .bold))
                    .foregroundStyle(Color.palsInk.opacity(near < 3 ? 0.8 : 0.4))
                    .fixedSize()
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(Motion.select) { position = minute }
        }
    }
}

#Preview {
    @Previewable @State var minutes: Int? = 10
    TimerDial(minutes: $minutes)
        .padding()
        .background(Color.palsOffWhite)
}

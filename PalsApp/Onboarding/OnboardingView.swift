import SwiftUI

struct OnboardingPage: Identifiable {
    let id: Int
    let lines: [String]
    let highlight: String
    let image: String

    static let all: [OnboardingPage] = [
        OnboardingPage(id: 0, lines: ["Get", "things", "done"], highlight: "together", image: "OnboardingHands"),
        OnboardingPage(id: 1, lines: ["Turn", "small", "time into"], highlight: "real progress", image: "OnboardingStopwatch"),
    ]
}

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var selection = 0
    private let pages = OnboardingPage.all

    var body: some View {
        ZStack(alignment: .top) {
            Color.palsIndigo.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(pages) { page in
                    OnboardingPageView(page: page, onNext: next)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            topBar
        }
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(pages) { page in
                    Capsule()
                        .fill(page.id == selection ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 20, height: 7)
                }
            }
            .animation(Motion.update, value: selection)
            .accessibilityElement()
            .accessibilityLabel("Page \(selection + 1) of \(pages.count)")

            HStack {
                Spacer()
                Button(action: onFinish) {
                    Text("Skip")
                        .font(.pals(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func next() {
        if selection < pages.count - 1 {
            withAnimation { selection += 1 }
        } else {
            onFinish()
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let onNext: () -> Void

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(alignment: .bottom) {
                // Illustration bleeds past the screen edges like in the design,
                // without affecting the layout of the content above it.
                Image(page.image)
                    .resizable()
                    .scaledToFit()
                    .containerRelativeFrame(.horizontal) { width, _ in width * 1.1 }
                    .offset(y: 50)
                    .ignoresSafeArea(edges: .bottom)
                    .accessibilityHidden(true)
            }
    }

    private var content: some View {
        VStack(spacing: 0) {
            HighlightHeadline(lines: page.lines, highlight: page.highlight, size: 64, color: .palsOffWhite)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 64)

            Button(action: onNext) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.palsIndigo)
                    .frame(width: 68, height: 68)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.tint(.white).interactive(), in: .circle)
            .accessibilityLabel("Next")
            .padding(.top, 32)

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}

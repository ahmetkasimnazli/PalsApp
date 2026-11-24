import SwiftUI

/// The back photo with the selfie in the corner. Tap the small one to swap them.
struct DualProofView: View {
    let proof: DualProof
    var cornerRadius: CGFloat = 24
    /// Inset size as a share of the width.
    var insetShare: CGFloat = 0.3
    var interactive = true

    @State private var swapped = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let insetWidth = width * insetShare
            let inner = max(10, cornerRadius * 0.55)
            ZStack(alignment: .topLeading) {
                photo(swapped ? proof.front : proof.back)
                    .frame(width: width, height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                photo(swapped ? proof.back : proof.front)
                    .frame(width: insetWidth, height: insetWidth * 4 / 3)
                    .clipShape(RoundedRectangle(cornerRadius: inner, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: inner, style: .continuous)
                        .strokeBorder(.black.opacity(0.85), lineWidth: max(1.5, width * 0.008)))
                    .padding(width * 0.035)
                    .onTapGesture {
                        guard interactive else { return }
                        withAnimation(Motion.select) { swapped.toggle() }
                    }
                    .accessibilityAddTraits(interactive ? .isButton : [])
                    .accessibilityLabel(interactive ? "Swap photos" : "")
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .sensoryFeedback(.selection, trigger: swapped)
        .accessibilityElement(children: interactive ? .contain : .ignore)
        .accessibilityLabel("\(proof.isYours ? "Your" : "\(proof.author)'s") moment")
    }

    private func photo(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
    }
}

/// A proof with who posted it and when, for strips and the viewer.
struct ProofCard: View {
    let proof: DualProof
    var onDark = false
    var interactive = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DualProofView(proof: proof, cornerRadius: 20, interactive: interactive)
            HStack(spacing: 8) {
                PalsAvatar(name: proof.author, photo: proof.isYours ? ProfilePhotoStore.load() : proof.authorPhoto,
                           color: proof.authorColor, size: 26, glass: false)
                Text(proof.isYours ? "You" : proof.author)
                    .font(.pals(15))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(proof.timeLabel)
                    .font(.palsBody(12))
                    .opacity(0.6)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(onDark ? Color.white : Color.palsInk)
        }
    }
}

/// "Today's moments" for a circle. Until you post your own, your pals' moments stay blurred.
struct ProofStrip: View {
    let model: HomeModel
    let circle: PalsCircle
    var onDark = false
    var onSnap: () -> Void

    @State private var viewing: DualProof?

    private var posted: Bool { model.myProof(in: circle) != nil }
    private var proofs: [DualProof] { model.proofs(in: circle) }
    private var palsProofs: [DualProof] { proofs.filter { !$0.isYours } }
    private var ink: Color { onDark ? .white : .palsInk }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's moments")
                    .font(.pals(20, weight: .bold))
                    .foregroundStyle(ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(proofs.count) posted")
                    .font(.palsBody(14))
                    .foregroundStyle(ink.opacity(0.6))
            }

            if proofs.isEmpty {
                empty
            } else if posted {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(proofs) { proof in
                            Button { viewing = proof } label: {
                                ProofCard(proof: proof, onDark: onDark)
                                    .frame(width: 150)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            } else {
                locked
            }
        }
        .fullScreenCover(item: $viewing) { proof in
            ProofViewer(proofs: proofs, startAt: proof.id)
        }
    }

    /// Blurred proofs behind a lock: posting yours is the way in.
    private var locked: some View {
        ZStack {
            HStack(spacing: 12) {
                ForEach(palsProofs.prefix(3)) { proof in
                    ProofCard(proof: proof, onDark: onDark)
                        .frame(width: 150)
                }
            }
            .blur(radius: 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("🔒")
                    .font(.system(size: 34))
                Text(palsProofs.count == 1 ? "1 pal posted" : "\(palsProofs.count) pals posted")
                    .font(.pals(19, weight: .bold))
                Text("Post your moment to see theirs.")
                    .font(.palsBody(14))
                    .opacity(0.75)
                Button(action: onSnap) {
                    Label("Snap my moment", systemImage: "camera.fill")
                        .font(.pals(16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
                .padding(.top, 4)
            }
            .foregroundStyle(ink)
            .padding(20)
            .frame(maxWidth: 280)
            .glassEffect(.regular, in: .rect(cornerRadius: 26))
        }
        .frame(height: 240)
    }

    private var empty: some View {
        HStack(spacing: 12) {
            Text("📸")
                .font(.system(size: 28))
            Text("No moments yet today. Be the first to post one.")
                .font(.palsBody(15))
                .foregroundStyle(ink.opacity(0.7))
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Full-screen swipe-through of a circle's proofs.
struct ProofViewer: View {
    let proofs: [DualProof]
    let startAt: DualProof.ID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            ScrollViewReader { reader in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(proofs) { proof in
                            ProofCard(proof: proof, onDark: true, interactive: true)
                                .padding(.horizontal, 20)
                                .containerRelativeFrame(.horizontal)
                                .id(proof.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
                // Open on the proof that was tapped.
                .onAppear { reader.scrollTo(startAt, anchor: .leading) }
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.interactive(), in: .circle)
            .padding(.trailing, 16)
            .padding(.top, 8)
            .accessibilityLabel("Close")
        }
        .preferredColorScheme(.dark)
    }
}

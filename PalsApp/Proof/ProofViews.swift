import SwiftUI

/// The name you set in onboarding or your profile, for your own avatar.
enum ProfileName {
    static var current: String {
        let name = UserDefaults.standard.string(forKey: "profileName") ?? ""
        return name.isEmpty ? "You" : name
    }
}

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
                PalsAvatar(name: proof.isYours ? ProfileName.current : proof.author,
                           photo: proof.isYours ? ProfilePhotoStore.load() : proof.authorPhoto,
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
    /// Pals' moments clear once you've posted and are back here to watch (not while the
    /// activity sheet is still covering the screen).
    private var showFaces: Bool { posted && model.activeActivity == nil }
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
            } else {
                row
                if !posted {
                    Button(action: onSnap) {
                        Label("Snap yours to see theirs", systemImage: "camera.fill")
                            .font(.pals(16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
                    .padding(.top, 4)
                }
            }
        }
        .fullScreenCover(item: $viewing) { proof in
            ProofViewer(proofs: proofs, startAt: proof.id)
        }
    }

    /// Your moment (or an empty slot to take it) first, then your pals' moments. Until you post,
    /// theirs stay blurred; posting brings them into focus one after another.
    private var row: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                if let mine = proofs.first(where: \.isYours) {
                    Button { viewing = mine } label: {
                        ProofCard(proof: mine, onDark: onDark).frame(width: 150)
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    Button(action: onSnap) { snapSlot }
                        .buttonStyle(PressableStyle())
                }

                ForEach(Array(palsProofs.enumerated()), id: \.element.author) { i, proof in
                    Button {
                        if posted { viewing = proof } else { onSnap() }
                    } label: {
                        MomentTile(proof: proof, faceUp: showFaces, order: i, onDark: onDark)
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
        .sensoryFeedback(.success, trigger: posted)
    }

    /// Where your moment goes until you take it.
    private var snapSlot: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(ink.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
                .background(ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26, weight: .semibold))
                        Text("Your moment")
                            .font(.pals(15, weight: .bold))
                    }
                    .foregroundStyle(ink)
                }
            HStack(spacing: 8) {
                PalsAvatar(name: ProfileName.current, photo: ProfilePhotoStore.load(), color: .palsBlue, size: 26, glass: false)
                Text("You")
                    .font(.pals(15))
                    .foregroundStyle(ink)
            }
        }
        .frame(width: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Snap your moment")
        .accessibilityAddTraits(.isButton)
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

/// A pal's moment, blurred with their face and a lock on it until you've posted yours,
/// then it comes into focus.
private struct MomentTile: View {
    let proof: DualProof
    let faceUp: Bool
    /// Its place in the row, so the moments clear one after another.
    let order: Int
    var onDark = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: Bool

    init(proof: DualProof, faceUp: Bool, order: Int, onDark: Bool) {
        self.proof = proof
        self.faceUp = faceUp
        self.order = order
        self.onDark = onDark
        _revealed = State(initialValue: faceUp)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                DualProofView(proof: proof, cornerRadius: 20, interactive: false)
                    .opacity(revealed ? 1 : 0)
                // Locked: only the main photo, blurred (the selfie would give it away).
                Color.clear
                    .overlay {
                        Image(uiImage: proof.back)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: revealed ? 0 : 16, opaque: true)
                            .overlay(Color.black.opacity(0.18))
                    }
                    .clipShape(shape)
                    .opacity(revealed ? 0 : 1)
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay { seal.opacity(revealed ? 0 : 1).scaleEffect(revealed ? 1.3 : 1) }

            HStack(spacing: 8) {
                PalsAvatar(name: proof.author, photo: proof.authorPhoto,
                           color: proof.authorColor, size: 26, glass: false)
                Text(proof.author)
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
        .onChange(of: faceUp) {
            if reduceMotion {
                revealed = faceUp
            } else {
                // A beat for the sheet to finish closing, then one moment after another.
                withAnimation(.easeOut(duration: 0.7).delay(0.45 + Double(order) * 0.2)) { revealed = faceUp }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(revealed ? "\(proof.author)'s moment" : "\(proof.author) posted a moment. Post yours to see it.")
    }

    /// The pal's face with a lock, on top of the blurred moment.
    private var seal: some View {
        PalsAvatar(name: proof.author, photo: proof.authorPhoto,
                   color: proof.authorColor, size: 58, glass: false)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.palsInk)
                    .frame(width: 24, height: 24)
                    .background(.white, in: Circle())
                    .offset(x: 4, y: 4)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
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

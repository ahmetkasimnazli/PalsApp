import AVFoundation
import AVKit
import SwiftUI

/// Full-screen moment camera, in two unhurried steps: first the back camera (what you're
/// doing), then the front camera (you). Each finished pair uses one of today's tries.
struct DualCameraView: View {
    let activity: CircleActivity
    let you: String
    /// Tries left when the camera opened.
    let triesLeft: Int
    var onTake: () -> Void
    var onPost: (DualProof) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = DualCamera()
    @State private var shot: DualProof?
    @State private var flash = false
    /// Takes finished since the camera opened.
    @State private var taken = 0
    /// Tries left when the camera opened. Kept fixed: the model's count drops as takes are
    /// made, and `taken` already accounts for those.
    @State private var startTries: Int?

    private var left: Int { max(0, (startTries ?? triesLeft) - taken) }
    /// Which try this is (1-based), for the header.
    private var tryNumber: Int { Model.tries - left + (shot == nil ? 1 : 0) }

    private enum Model { static let tries = HomeModel.momentTries }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 12)
                if let shot {
                    DualProofView(proof: shot, cornerRadius: 28)
                        .padding(.horizontal, 16)
                        .transition(.opacity)
                } else {
                    viewfinder
                }
                Spacer(minLength: 12)
                controls
                    .frame(height: 120)
            }

            // A white blink on each capture.
            Color.white
                .opacity(flash ? 0.7 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .onAppear { if startTries == nil { startTries = triesLeft } }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .medium), trigger: camera.shots)
        // Volume up/down (and Camera Control) take the photo, like the Camera app. While this is
        // on, the buttons don't change the volume.
        .onCameraCaptureEvent(isEnabled: canShoot) { event in
            if event.phase == .ended { shoot() }
        }
    }

    /// The shutter can fire: the camera is live, nothing is being captured or reviewed, a try is left.
    private var canShoot: Bool {
        shot == nil && camera.status == .ready && !camera.isCapturing && left > 0
    }

    private var header: some View {
        HStack {
            // Out of tries with an unposted take: the only way on is to post it.
            if !(shot != nil && left == 0) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Close")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 0) {
                Text("Moment")
                    .font(.pals(20, weight: .bold))
                Text("\(activity.emoji) \(activity.title)")
                    .font(.palsBody(14))
                    .opacity(0.7)
                    .lineLimit(1)
                Text("Try \(min(max(tryNumber, 1), Model.tries)) of \(Model.tries)")
                    .font(.pals(13))
                    .opacity(0.55)
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)

            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var viewfinder: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        ZStack {
            switch camera.status {
            case .starting:
                shape.fill(.white.opacity(0.08))
                ProgressView().tint(.white)
            case .ready:
                CameraPreview(session: camera.session)
                    .clipShape(shape)
                if let back = camera.backShot {
                    // The back photo stays as a small inset while the selfie is taken.
                    Image(uiImage: back)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 147)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.scale(scale: 0.9, anchor: .topLeading).combined(with: .opacity))
                }
                Text(camera.backShot == nil ? "1 / 2 · What you're doing" : "2 / 2 · Now you 😁")
                    .font(.pals(17, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect(.regular, in: .capsule)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 16)
                    .contentTransition(.opacity)
            case .denied:
                shape.fill(.white.opacity(0.08))
                message(icon: "camera.fill", title: "Camera access is off",
                        text: "Pals needs the camera for your moment.",
                        button: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .unavailable:
                shape.fill(.white.opacity(0.08))
                message(icon: "camera.badge.ellipsis", title: "No camera here",
                        text: "The Simulator can't take photos. Use sample photos to try the flow.",
                        button: "Use sample photos") {
                    guard left > 0 else { return }
                    finishTake(DemoProofArt.make(for: activity, author: you, color: .palsBlue,
                                                 photo: ProfilePhotoStore.load(), isYours: true,
                                                 variant: taken % 3 + 1))
                }
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .padding(.horizontal, 16)
        .animation(Motion.select, value: camera.backShot != nil)
    }

    private func message(icon: String, title: String, text: String, button: String,
                         action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
            Text(title)
                .font(.pals(22, weight: .bold))
            Text(text)
                .font(.palsBody(15))
                .opacity(0.7)
                .multilineTextAlignment(.center)
            Button(button, action: action)
                .font(.pals(17))
                .buttonStyle(.glass)
                .controlSize(.large)
                .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(28)
    }

    @ViewBuilder
    private var controls: some View {
        if let shot {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if left > 0 {
                        Button {
                            withAnimation(Motion.appear) { self.shot = nil }
                            camera.reset()
                        } label: {
                            Label("Retake", systemImage: "arrow.counterclockwise")
                                .font(.pals(18))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }

                    Button {
                        onPost(shot)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Post")
                            Image(systemName: "paperplane.fill")
                        }
                        .font(.pals(20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .glassEffect(.regular.tint(.palsBlue).interactive(), in: .capsule)
                }
                Text(left == 0 ? "That was your last try today." : left == 1 ? "1 retake left" : "\(left) retakes left")
                    .font(.palsBody(14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
        } else if camera.status == .ready {
            HStack {
                // Redo the first photo before taking the selfie (doesn't use a try).
                Button {
                    withAnimation(Motion.select) { camera.reset() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                }
                .buttonStyle(PressableStyle())
                .glassEffect(.regular.interactive(), in: .circle)
                .opacity(camera.backShot == nil ? 0 : 1)
                .disabled(camera.backShot == nil)
                .accessibilityLabel("Retake the first photo")
                .frame(maxWidth: .infinity)

                Button(action: shoot) {
                    Circle()
                        .strokeBorder(.white, lineWidth: 5)
                        .frame(width: 84, height: 84)
                        .overlay(Circle().fill(.white).padding(10))
                        .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .disabled(!canShoot)
                .opacity(canShoot ? 1 : 0.4)
                .accessibilityLabel(camera.backShot == nil ? "Take the photo" : "Take the selfie")

                Color.clear.frame(width: 52, height: 52).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
        }
    }

    /// First press: back photo, then the camera flips. Second press: the selfie.
    private func shoot() {
        guard canShoot else { return }
        Task {
            if camera.backShot == nil {
                await camera.captureBack()
                blink()
            } else if let back = camera.backShot, let front = await camera.captureFront() {
                blink()
                finishTake(DualProof(back: back, front: front, author: you, time: .now, isYours: true))
            }
        }
    }

    private func finishTake(_ proof: DualProof) {
        taken += 1
        onTake()
        withAnimation(Motion.appear) { shot = proof }
    }

    private func blink() {
        flash = true
        withAnimation(.easeOut(duration: 0.25)) { flash = false }
    }
}

// MARK: - Camera

@Observable
final class DualCamera: NSObject {
    enum Status { case starting, ready, denied, unavailable }

    var status: Status = .starting
    var isCapturing = false
    /// The back photo, shown while the front one is being taken.
    var backShot: UIImage?
    /// Bumped on every shutter, for haptics.
    var shots = 0

    @ObservationIgnored nonisolated(unsafe) let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private var input: AVCaptureDeviceInput?
    @ObservationIgnored private var pending: CheckedContinuation<UIImage?, Never>?

    func start() async {
        #if targetEnvironment(simulator)
        status = .unavailable
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { status = .denied; return }
        default:
            status = .denied
            return
        }
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            status = .unavailable
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        use(.back)
        await run { $0.startRunning() }
        status = .ready
        #endif
    }

    func stop() {
        let session = session
        Task.detached { session.stopRunning() }
    }

    func reset() {
        backShot = nil
        use(.back)
    }

    /// Takes the back photo, then flips to the front camera for the selfie.
    func captureBack() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }
        guard let back = await capture() else { return }
        shots += 1
        backShot = back
        use(.front)
    }

    func captureFront() async -> UIImage? {
        guard !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }
        guard let front = await capture() else { return nil }
        shots += 1
        return front
    }

    private func use(_ position: AVCaptureDevice.Position) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let newInput = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        if let input { session.removeInput(input) }
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            input = newInput
        }
        session.commitConfiguration()
    }

    private func capture() async -> UIImage? {
        await withCheckedContinuation { continuation in
            pending = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func run(_ work: @escaping @Sendable (AVCaptureSession) -> Void) async {
        let session = session
        await Task.detached { work(session) }.value
    }

    fileprivate func finished(with data: Data?) {
        let image = data.flatMap(UIImage.init(data:)).map { image in
            image.preparingThumbnail(of: image.size.scaled(toMaxSide: 1400)) ?? image
        }
        pending?.resume(returning: image)
        pending = nil
    }
}

extension DualCamera: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        Task { @MainActor in self.finished(with: data) }
    }
}

private extension CGSize {
    func scaled(toMaxSide side: CGFloat) -> CGSize {
        let ratio = min(1, side / Swift.max(width, height))
        return CGSize(width: width * ratio, height: height * ratio)
    }
}

/// Live camera feed.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

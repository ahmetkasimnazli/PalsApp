import AVFoundation
import SwiftUI

/// Full-screen proof camera. One shutter press takes the back photo, flips to the front
/// camera and takes the selfie a moment later, like BeReal. Then you review and post.
struct DualCameraView: View {
    let activity: CircleActivity
    let you: String
    var onPost: (DualProof) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = DualCamera()
    @State private var shot: DualProof?
    @State private var flash = false

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
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .sensoryFeedback(.impact(weight: .medium), trigger: camera.shots)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressableStyle())
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Close")

            Spacer()

            VStack(spacing: 0) {
                Text("Moment")
                    .font(.pals(20, weight: .bold))
                Text("\(activity.emoji) \(activity.title)")
                    .font(.palsBody(14))
                    .opacity(0.7)
                    .lineLimit(1)
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
                if camera.isCapturing {
                    Text(camera.backShot == nil ? "Hold still…" : "Now smile! 😁")
                        .font(.pals(22, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 20)
                }
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
                    withAnimation(Motion.appear) {
                        shot = DemoProofArt.make(for: activity, author: you, color: .palsBlue,
                                                 photo: ProfilePhotoStore.load(), isYours: true)
                    }
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
            HStack(spacing: 12) {
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
            .padding(.horizontal, 20)
        } else if camera.status == .ready {
            Button(action: shoot) {
                Circle()
                    .strokeBorder(.white, lineWidth: 5)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().fill(.white).padding(10))
                    .contentShape(Circle())
            }
            .buttonStyle(PressableStyle())
            .disabled(camera.isCapturing)
            .opacity(camera.isCapturing ? 0.4 : 1)
            .accessibilityLabel("Take your moment")
        }
    }

    private func shoot() {
        Task {
            guard let pair = await camera.captureBoth(onEachShot: blink) else { return }
            withAnimation(Motion.appear) {
                shot = DualProof(back: pair.back, front: pair.front, author: you, time: .now, isYours: true)
            }
        }
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

    /// Back photo, flip, a beat to let exposure settle, selfie.
    func captureBoth(onEachShot: @escaping () -> Void) async -> (back: UIImage, front: UIImage)? {
        guard !isCapturing else { return nil }
        isCapturing = true
        defer { isCapturing = false }

        guard let back = await capture() else { return nil }
        shots += 1
        onEachShot()
        backShot = back
        use(.front)
        try? await Task.sleep(for: .milliseconds(700))
        guard let front = await capture() else { return nil }
        shots += 1
        onEachShot()
        return (back, front)
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

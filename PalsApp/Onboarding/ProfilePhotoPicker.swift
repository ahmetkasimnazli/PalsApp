import PhotosUI
import SwiftUI

/// The "hand holding a polaroid" illustration from the design. Tapping it opens the
/// photo library; the picked photo is placed inside the polaroid.
struct ProfilePhotoPicker: View {
    @Binding var photo: UIImage?

    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false

    // Geometry of the polaroid's photo area, in points of the 411 × 284.5 illustration
    // (measured from the exported Sketch bitmap).
    private enum Polaroid {
        static let imageSize = CGSize(width: 411, height: 284.5)
        static let photoCenter = CGPoint(x: 228.5, y: 111.6)
        static let photoSize = CGSize(width: 125, height: 118)
        static let rotation = Angle.degrees(10.9)
        static let badgeCenter = CGPoint(x: 266.5, y: 175)
        static let badgeDiameter: CGFloat = 44
    }

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Image("ProfilePhotoPrompt")
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { proxy in
                        let scale = proxy.size.width / Polaroid.imageSize.width
                        polaroidPhoto(scale: scale)
                        badge(scale: scale)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(photo == nil ? "Add profile photo" : "Change profile photo")
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    @ViewBuilder
    private func polaroidPhoto(scale: CGFloat) -> some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: Polaroid.photoSize.width * scale, height: Polaroid.photoSize.height * scale)
                .clipped()
                .rotationEffect(Polaroid.rotation)
                .position(x: Polaroid.photoCenter.x * scale, y: Polaroid.photoCenter.y * scale)
                .transition(.opacity)
        } else if isLoading {
            ProgressView()
                .tint(.white)
                .position(x: Polaroid.photoCenter.x * scale, y: Polaroid.photoCenter.y * scale)
        }
    }

    /// Redrawn on top so it stays visible above a picked photo.
    private func badge(scale: CGFloat) -> some View {
        let diameter = Polaroid.badgeDiameter * scale
        return Image(systemName: photo == nil ? "plus" : "pencil")
            .font(.system(size: diameter * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular.tint(.palsBlue), in: .circle)
            .position(x: Polaroid.badgeCenter.x * scale, y: Polaroid.badgeCenter.y * scale)
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let resized = await image.byPreparingThumbnail(ofSize: image.size.fitting(maxSide: 1024)) ?? image
        withAnimation(.easeInOut) { photo = resized }
    }
}

private extension CGSize {
    func fitting(maxSide: CGFloat) -> CGSize {
        let ratio = min(1, maxSide / Swift.max(width, height))
        return CGSize(width: width * ratio, height: height * ratio)
    }
}

/// Saves / loads the profile photo as a JPEG in Application Support.
enum ProfilePhotoStore {
    private static var url: URL {
        URL.applicationSupportDirectory.appending(path: "profile-photo.jpg")
    }

    static func save(_ image: UIImage?) {
        guard let image, let data = image.jpegData(compressionQuality: 0.85) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: url.path(percentEncoded: false))
    }
}

#Preview {
    @Previewable @State var photo: UIImage?
    ProfilePhotoPicker(photo: $photo)
        .padding()
        .background(Color.palsOffWhite)
}

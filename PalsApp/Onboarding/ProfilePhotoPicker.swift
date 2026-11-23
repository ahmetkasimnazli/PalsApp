import PhotosUI
import SwiftUI

/// Big round avatar: tap to pick a photo from the library. Shows the photo, or your
/// initial (live, as you type your name) so you see exactly what your pals will see.
struct ProfilePhotoPicker: View {
    @Binding var photo: UIImage?
    var name: String = ""
    var size: CGFloat = 168

    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false

    private var ring: CGFloat { max(4, size * 0.05) }
    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Color.palsPink
                    if isLoading {
                        ProgressView().tint(.white)
                    } else if initial.isEmpty {
                        Image(systemName: "camera.fill")
                            .font(.system(size: size * 0.24, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(initial)
                            .font(.palsDisplay(size * 0.42))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(width: size - 2 * ring, height: size - 2 * ring)
            .clipShape(Circle())
            .padding(ring)
            .glassEffect(.regular, in: .circle)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: photo == nil ? "plus" : "pencil")
                    .font(.system(size: size * 0.11, weight: .bold))
                    .foregroundStyle(Color.palsIndigo)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .glassEffect(.regular.tint(.white), in: .circle)
                    .offset(x: -size * 0.02, y: -size * 0.02)
            }
            .animation(.snappy, value: initial)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(photo == nil ? "Add profile photo" : "Change profile photo")
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
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
    ProfilePhotoPicker(photo: $photo, name: "Ahmet")
        .padding()
        .background(Color.palsIndigo)
}

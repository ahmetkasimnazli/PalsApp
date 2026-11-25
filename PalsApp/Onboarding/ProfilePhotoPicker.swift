import PhotosUI
import SwiftUI

/// Big round avatar: tap to pick a photo from the library or use one of your Memoji. Shows the
/// photo, or your initial (live, as you type your name) so you see exactly what your pals will see.
struct ProfilePhotoPicker: View {
    @Binding var photo: UIImage?
    var name: String = ""
    var size: CGFloat = 168
    /// Also shows "Photo" and "Memoji" buttons under the avatar (onboarding).
    var showsOptions = false
    /// Colours for the option buttons: light on the onboarding's blue, dark on a light sheet.
    var onDark = true

    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false
    @State private var pickingPhoto = false
    @State private var pickingMemoji = false

    private var ring: CGFloat { max(4, size * 0.05) }
    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            Menu {
                Button { pickingPhoto = true } label: { Label("Choose a photo", systemImage: "photo.on.rectangle") }
                Button { pickingMemoji = true } label: { Label("Use my Memoji", systemImage: "face.smiling") }
            } label: {
                avatar
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(photo == nil ? "Add profile photo or Memoji" : "Change profile photo")

            if showsOptions {
                // Two drops of glass melted into one: the container's spacing is wider than the
                // gap between them, so their shapes blend together at rest.
                GlassEffectContainer(spacing: 28) {
                    HStack(spacing: 2) {
                        option("Photo", systemImage: "photo.on.rectangle") { pickingPhoto = true }
                        option("Memoji", systemImage: "face.smiling") { pickingMemoji = true }
                    }
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $selection, matching: .images, photoLibrary: .shared())
        .sheet(isPresented: $pickingMemoji) {
            MemojiPickerSheet { image in
                withAnimation(Motion.appear) { photo = image }
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
            selection = nil
        }
    }

    private var avatar: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else if let bundled = PalsAvatar.bundledPhoto(for: name) {
                // Same fallback the avatar uses everywhere else, so this matches what pals see.
                Image(uiImage: bundled)
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
                // A plain disc: Liquid Glass doesn't draw inside a Menu's label.
                .background(.white, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                .offset(x: -size * 0.02, y: -size * 0.02)
        }
        .animation(Motion.select, value: initial)
    }

    private func option(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.pals(13, weight: .bold))
            }
            .foregroundStyle(onDark ? Color.white : Color.palsInk)
            .frame(width: 76, height: 76)
            .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .glassEffect(.regular.interactive(), in: .circle)
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let resized = await image.byPreparingThumbnail(ofSize: image.size.fitting(maxSide: 1024)) ?? image
        withAnimation(Motion.appear) { photo = resized }
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

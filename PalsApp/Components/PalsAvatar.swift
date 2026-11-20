import SwiftUI

/// Round avatar: the photo if there is one, then a bundled profile photo for the name,
/// otherwise initials on a brand color.
struct PalsAvatar: View {
    let name: String
    var photo: UIImage?
    var color: Color = .palsIndigo
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else if let memoji {
                // Bundled profile photos come with their own colored background.
                Image(uiImage: memoji)
                    .resizable()
                    .scaledToFill()
            } else {
                color
                Text(initials)
                    .font(.palsDisplay(size * 0.38))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size - 2 * ring, height: size - 2 * ring)
        .clipShape(Circle())
        // Glass ring: the photo sits inside a slightly larger glass disc.
        .padding(ring)
        .glassEffect(.regular, in: .circle)
        .frame(width: size, height: size)
        .accessibilityLabel(name)
    }

    private var ring: CGFloat { max(3, size * 0.06) }

    /// Profile photo bundled as "Avatar<FirstName>" (e.g. AvatarAlessia), if there is one.
    private var memoji: UIImage? {
        guard let first = name.split(separator: " ").first else { return nil }
        return UIImage(named: "Avatar\(first.prefix(1).uppercased())\(first.dropFirst().lowercased())")
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

#Preview {
    HStack {
        PalsAvatar(name: "Alessia", color: .palsPink)
        PalsAvatar(name: "Kimia", color: .palsPink)
        PalsAvatar(name: "Someone New", color: .palsBlue, size: 90)
    }
    .padding()
    .background(Color.palsOffWhite)
}

import SwiftUI

/// A sync problem at the top of the screen: what's wrong and what happens next. It doesn't block
/// anything, and it goes away by itself once a sync works again.
struct SyncBanner: View {
    let issue: PalsError
    var onRetry: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.pals(15, weight: .bold))
                Text(issue.message)
                    .font(.palsBody(13))
                    .foregroundStyle(Color.palsInk.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.palsInk)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Offline fixes itself when the connection is back; everything else can be retried.
            if issue.kind != .offline && issue.kind != .signedOut {
                Button("Try again", action: onRetry)
                    .font(.pals(14, weight: .bold))
                    .foregroundStyle(Color.palsBlue)
                    .frame(minHeight: 44)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.palsInk.opacity(0.5))
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }

    private var icon: String {
        switch issue.kind {
        case .offline: "wifi.slash"
        case .signedOut: "person.crop.circle.badge.exclamationmark"
        case .busy: "clock.arrow.circlepath"
        default: "exclamationmark.icloud"
        }
    }

    private var tint: Color {
        switch issue.kind {
        case .offline, .busy: Color(hex: 0xF5A524)
        default: Color.palsPink
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SyncBanner(issue: .offline, onRetry: {}, onClose: {})
        SyncBanner(issue: .unknown, onRetry: {}, onClose: {})
    }
    .padding()
    .background(Color.palsIndigo)
}

import SwiftUI
import UserNotifications

/// Profile tab: your player card, your circles, a few settings and the demo tools.
struct ProfileView: View {
    let model: HomeModel
    @Binding var photo: UIImage?
    var onOpenCircle: (PalsCircle.ID) -> Void
    var onRestartOnboarding: () -> Void

    @AppStorage("profileName") private var name = ""
    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 18 * 60
    @AppStorage("prankHaptics") private var prankHaptics = true

    @State private var editing = false
    @State private var didReset = false
    @State private var notificationsDenied = false

    private var displayName: String { name.isEmpty ? "Pal" : name }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HighlightHeadline(lines: ["Your"], highlight: "profile", size: 52)
                    .padding(.top, 12)

                PlayerCard(name: displayName, photo: photo, streak: model.streakDays,
                           freezes: model.freezes, circles: model.circles.count) {
                    editing = true
                }
                .padding(.top, 20)

                sectionTitle("Your circles")
                VStack(spacing: 8) {
                    ForEach(model.circles) { circle in
                        circleRow(circle)
                    }
                }

                sectionTitle("Settings")
                group {
                    reminderRow
                    divider
                    toggleRow(icon: "hand.tap.fill", color: .palsPink, title: "Prank haptics",
                              detail: "Feel the slap when a pal pranks you", isOn: $prankHaptics)
                    divider
                    infoRow(icon: "icloud.fill", color: .palsBlue, title: "iCloud account",
                            detail: "Pals uses it instead of a sign-up")
                }

                sectionTitle("Demo")
                group {
                    actionRow(icon: "bell.badge.fill", color: .palsPink, title: "Get pranked now") {
                        model.receiveDemoPrank()
                    }
                    divider
                    actionRow(icon: didReset ? "checkmark" : "arrow.counterclockwise", color: .palsIndigo,
                              title: didReset ? "Today reset" : "Reset today") {
                        withAnimation { model.resetToday() }
                        didReset = true
                    }
                    divider
                    actionRow(icon: "sparkles", color: .palsIndigo, title: "Restart onboarding",
                              action: onRestartOnboarding)
                }

                Text("Pals \(appVersion)")
                    .font(.palsBody(13))
                    .foregroundStyle(Color.palsInk.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        // Pull down to sync with iCloud now.
        .refreshable { await model.refresh() }
        .background(Color.palsOffWhite.ignoresSafeArea())
        .onDisappear { didReset = false }
        .sheet(isPresented: $editing) {
            EditProfileSheet(name: name, photo: photo) { newName, newPhoto in
                name = newName
                photo = newPhoto
                ProfilePhotoStore.save(newPhoto)
                model.profileChanged()
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Circles

    private func circleRow(_ circle: PalsCircle) -> some View {
        let done = model.isDone(in: circle)
        let revealed = model.isRevealed(circle)
        return Button { onOpenCircle(circle.id) } label: {
            HStack(spacing: 14) {
                Text(circle.emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(circle.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(circle.name)
                        .font(.pals(18))
                        .foregroundStyle(Color.palsInk)
                    Text(revealed ? "\(circle.today.emoji) \(circle.today.title)" : "🃏 Card not drawn yet")
                        .font(.palsBody(14))
                        .foregroundStyle(Color.palsInk.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: 0x22C55E))
                        .accessibilityLabel("Done today")
                }
                MiniAvatars(people: Array(circle.friends.prefix(3)), size: 24)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.palsInk.opacity(0.3))
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Settings

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            toggleRow(icon: "alarm.fill", color: .palsBlue, title: "Daily reminder",
                      detail: notificationsDenied ? "Notifications are off for Pals in Settings"
                                                  : "A nudge to draw today's card",
                      isOn: Binding(get: { reminderOn }, set: setReminder))
            if reminderOn {
                DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    .font(.pals(16))
                    .foregroundStyle(Color.palsInk)
                    .tint(.palsBlue)
                    .padding(.leading, 50)
                    .transition(.opacity)
            }
        }
        .animation(Motion.expand, value: reminderOn)
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60,
                                  second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
            DailyReminder.schedule(minutes: reminderMinutes)
        }
    }

    /// Asks for notification permission the moment you turn the reminder on, not at launch.
    private func setReminder(_ on: Bool) {
        guard on else {
            reminderOn = false
            DailyReminder.cancel()
            return
        }
        Task {
            let granted = await DailyReminder.requestPermission()
            notificationsDenied = !granted
            reminderOn = granted
            if granted { DailyReminder.schedule(minutes: reminderMinutes) }
        }
    }

    // MARK: Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.pals(20, weight: .bold))
            .foregroundStyle(Color.palsInk)
            .padding(.top, 28)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var divider: some View {
        Divider().padding(.leading, 50)
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(color, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .contentTransition(.symbolEffect(.replace))
    }

    private func toggleRow(icon name: String, color: Color, title: String, detail: String,
                           isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                icon(name, color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.pals(17))
                        .foregroundStyle(Color.palsInk)
                    Text(detail)
                        .font(.palsBody(13))
                        .foregroundStyle(Color.palsInk.opacity(0.55))
                }
            }
        }
        .tint(.palsBlue)
        .frame(minHeight: 56)
    }

    private func infoRow(icon name: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            icon(name, color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                Text(detail)
                    .font(.palsBody(13))
                    .foregroundStyle(Color.palsInk.opacity(0.55))
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: 0x22C55E))
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private func actionRow(icon name: String, color: Color, title: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon(name, color)
                Text(title)
                    .font(.pals(17))
                    .foregroundStyle(Color.palsInk)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

// MARK: - Player card

/// You, as a card: same surface and shapes as the activity cards.
private struct PlayerCard: View {
    let name: String
    let photo: UIImage?
    let streak: Int
    let freezes: Int
    let circles: Int
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                PalsAvatar(name: name, photo: photo, size: 92)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Edit profile")
            }

            Text(name)
                .font(.palsDisplay(38))
                .tracking(-1)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 8) {
                stat("🔥", "\(streak)", streak == 1 ? "day" : "days")
                stat("❄️", "\(freezes)", freezes == 1 ? "freeze" : "freezes")
                stat("👯", "\(circles)", circles == 1 ? "circle" : "circles")
            }
        }
        .padding(20)
        .background(CardSurface(color: .palsBlue, pattern: 2, cornerRadius: 28))
        .shadow(color: Color.palsBlue.opacity(0.25), radius: 18, y: 10)
    }

    private func stat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(emoji) \(value)")
                .font(.pals(20, weight: .bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.palsBody(13))
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Edit sheet

private struct EditProfileSheet: View {
    var onSave: (_ name: String, _ photo: UIImage?) -> Void

    @State private var name: String
    @State private var photo: UIImage?
    @Environment(\.dismiss) private var dismiss

    init(name: String, photo: UIImage?, onSave: @escaping (String, UIImage?) -> Void) {
        _name = State(initialValue: name)
        _photo = State(initialValue: photo)
        self.onSave = onSave
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ProfilePhotoPicker(photo: $photo, name: name, size: 140)
                    .padding(.top, 8)

                if photo != nil {
                    Button("Remove photo", role: .destructive) {
                        withAnimation(Motion.appear) { photo = nil }
                    }
                    .font(.pals(15))
                }

                TextField("Your name", text: $name)
                    .font(.pals(20))
                    .foregroundStyle(Color.palsInk)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 22)
                    .frame(height: 58)
                    .background(.white, in: Capsule())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.palsOffWhite.ignoresSafeArea())
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(trimmed.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, photo)
        dismiss()
    }
}

// MARK: - Daily reminder

/// One repeating local notification at the time you pick.
enum DailyReminder {
    private static let id = "dailyReminder"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func schedule(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Today's card is waiting 🃏"
        content.body = "Draw it and get it done before your pals prank you."
        content.sound = .default

        var time = DateComponents()
        time.hour = minutes / 60
        time.minute = minutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

#Preview {
    @Previewable @State var photo: UIImage?
    ProfileView(model: HomeModel(), photo: $photo, onOpenCircle: { _ in }, onRestartOnboarding: {})
}

import CoreHaptics

/// Custom haptics that follow a prank's animation: you feel the wind-up, the hit and the sting.
@MainActor
final class PrankHaptics {
    static let shared = PrankHaptics()

    private var engine: CHHapticEngine?

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
    }

    /// Plays the pattern for `kind`, with the hit landing `impactAt` seconds from now.
    func play(_ kind: PrankKind, impactAt: TimeInterval) {
        guard let engine else { return }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: pattern(for: kind, impactAt: impactAt))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nice-to-have; the animation still plays without them.
        }
    }

    private func pattern(for kind: PrankKind, impactAt t: TimeInterval) throws -> CHHapticPattern {
        switch kind {
        case .slap:
            return try CHHapticPattern(events: [
                // Whoosh: a soft rumble that builds while the arm swings.
                continuous(intensity: 0.4, sharpness: 0.15, at: max(0, t - 0.28), duration: 0.28),
                // The crack of the hand landing.
                transient(intensity: 1, sharpness: 0.95, at: t),
                transient(intensity: 0.7, sharpness: 0.5, at: t + 0.05),
                // The sting, fading out.
                continuous(intensity: 0.7, sharpness: 0.35, at: t + 0.05, duration: 0.45),
            ], parameterCurves: [
                ramp(.hapticIntensityControl, from: 0.2, to: 1, at: max(0, t - 0.28), over: 0.28),
                ramp(.hapticIntensityControl, from: 1, to: 0, at: t + 0.05, over: 0.45),
            ])

        case .egg:
            return try CHHapticPattern(events: [
                // Shell cracking: two quick, sharp taps.
                transient(intensity: 0.9, sharpness: 1, at: t),
                transient(intensity: 0.6, sharpness: 0.9, at: t + 0.07),
                // Squish: a soft, dull ooze that slowly fades.
                continuous(intensity: 0.5, sharpness: 0.05, at: t + 0.1, duration: 0.7),
            ], parameterCurves: [
                ramp(.hapticIntensityControl, from: 1, to: 0, at: t + 0.1, over: 0.7),
            ])
        }
    }

    private func transient(intensity: Float, sharpness: Float, at time: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time)
    }

    private func continuous(intensity: Float, sharpness: Float, at time: TimeInterval,
                            duration: TimeInterval) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: time, duration: duration)
    }

    private func ramp(_ parameter: CHHapticDynamicParameter.ID, from start: Float, to end: Float,
                      at time: TimeInterval, over duration: TimeInterval) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: parameter, controlPoints: [
            CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: start),
            CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: end),
        ], relativeTime: time)
    }
}

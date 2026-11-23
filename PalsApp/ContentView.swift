//
//  ContentView.swift
//  PalsApp
//
//  Created by Ahmet Kasım Nazlı on 18.11.2026.
//

import SwiftUI

/// Drives the first-run flow: Splash → Onboarding → Welcome → Profile setup → Home.
struct ContentView: View    {
    private enum Step {
        case splash, onboarding, welcome, profile, home
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("profileName") private var profileName = ""

    @State private var step: Step = .splash

    var body: some View {
        ZStack {
            Group {
            switch step {
            case .splash:
                SplashView()
                    .task {
                        try? await Task.sleep(for: .seconds(1))
                        go(to: hasCompletedOnboarding ? .home : .onboarding)
                    }
            case .onboarding:
                OnboardingView { go(to: .welcome) }
                    .environment(\.colorScheme, .dark)
            case .welcome:
                WelcomeView { go(to: .profile) }
                    .environment(\.colorScheme, .dark)
            case .profile:
                ProfileSetupView(
                    onFinish: { name, photo in
                        profileName = name
                        ProfilePhotoStore.save(photo)
                        finishOnboarding()
                    },
                    onSkip: finishOnboarding
                )
                // Onboarding sits on brand blue: dark glass and keyboard, like the Orbit tab.
                .environment(\.colorScheme, .dark)
            case .home:
                MainTabView(name: profileName) {
                    hasCompletedOnboarding = false
                    go(to: .onboarding)
                }
            }
            }
            .transition(.opacity)
        }
    }

    private func go(to next: Step) {
        withAnimation(.easeInOut(duration: 0.35)) { step = next }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        go(to: .home)
    }
}

#Preview {
    ContentView()
}

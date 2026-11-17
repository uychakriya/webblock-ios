import SwiftUI

/// Signed out → sign-in screen. Signed in → the list of live websites and their portals.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if appState.isSignedIn {
                HomeView()
                    .transition(.opacity)
            } else if !hasSeenOnboarding {
                OnboardingView { hasSeenOnboarding = true }
                    // Leaves with a gentle lift and fade into sign-in.
                    .transition(.asymmetric(insertion: .opacity,
                                            removal: .opacity.combined(with: .scale(scale: 1.04))))
            } else {
                SignInView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: appState.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
    }
}

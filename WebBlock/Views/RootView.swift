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
                    .transition(.opacity)
            } else {
                SignInView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isSignedIn)
        .animation(.easeInOut(duration: 0.25), value: hasSeenOnboarding)
    }
}

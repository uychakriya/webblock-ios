import SwiftUI

@main
struct WebBlockApp: App {
    @State private var appState = AppState()

    init() {
        DMSans.register()
        // Blue large titles like the page headers in the Figma design.
        let brand = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0x6E9BEA) : UIColor(hex: 0x4379D6) }
        // Standard-sized page titles (iOS default large title is 34pt, which feels oversized here).
        let titleFont = UIFont.systemFont(ofSize: 26, weight: .bold)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: brand, .font: titleFont]
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.titleTextAttributes = [.foregroundColor: brand]
        scrolled.largeTitleTextAttributes = [.foregroundColor: brand, .font: titleFont]
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.wbBrand)
        }
    }
}
